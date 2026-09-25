package com.ababilx.app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.ParcelFileDescriptor
import android.os.ProxyFileDescriptorCallback
import android.os.storage.StorageManager
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.OsConstants
import java.io.FileNotFoundException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Hands a Ghost Chat file to another app WITHOUT it ever being written to
 * disk.
 *
 * A Ghost Chat promises nothing is stored, and a PDF or a video cannot be
 * drawn in-app — it has to be opened by a viewer, which means handing that app
 * something it can read. Writing a temp file, even app-private and deleted
 * afterwards, leaves the bytes in the clear for as long as it exists, and a
 * process killed in between leaves them behind entirely.
 *
 * So the bytes stay in this process's memory and are served from there, which
 * is Signal's model (`BlobProvider` / `PartProvider` memory blobs). The
 * descriptor handed out is RAM-backed and SEEKABLE: a pipe would be simpler,
 * but a pipe cannot seek and most PDF and video viewers seek, so they would
 * fail or read nothing. API 26+ gets `openProxyFileDescriptor` reading
 * straight out of the array; older devices fall back to a pipe, which still
 * works for images.
 *
 * Every blob is dropped and its array zeroed on the burn ([clear]), which the
 * Dart side also calls at app start.
 */
class GhostBlobProvider : ContentProvider() {

  private class Blob(val bytes: ByteArray, val name: String, val mime: String)

  override fun onCreate(): Boolean = true

  override fun getType(uri: Uri): String? = blobs[idOf(uri)]?.mime

  /**
   * Viewers ask for the display name and size before opening. Answering with
   * the real name keeps the other app's title bar honest; nothing else about
   * the file is exposed.
   */
  override fun query(
    uri: Uri,
    projection: Array<out String>?,
    selection: String?,
    selectionArgs: Array<out String>?,
    sortOrder: String?,
  ): Cursor? {
    val blob = blobs[idOf(uri)] ?: return null
    val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
    val cursor = MatrixCursor(columns)
    val row = arrayOfNulls<Any>(columns.size)
    columns.forEachIndexed { index, column ->
      row[index] = when (column) {
        OpenableColumns.DISPLAY_NAME -> blob.name
        OpenableColumns.SIZE -> blob.bytes.size.toLong()
        else -> null
      }
    }
    cursor.addRow(row)
    return cursor
  }

  override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
    if (mode != "r") throw FileNotFoundException("Ghost blobs are read-only")
    val blob = blobs[idOf(uri)] ?: throw FileNotFoundException("No such ghost blob")
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      seekableDescriptor(providerContext(), blob.bytes)
    } else {
      pipeDescriptor(blob.bytes)
    }
  }

  override fun insert(uri: Uri, values: ContentValues?): Uri? =
    throw UnsupportedOperationException()

  override fun update(
    uri: Uri,
    values: ContentValues?,
    selection: String?,
    selectionArgs: Array<out String>?,
  ): Int = throw UnsupportedOperationException()

  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
    throw UnsupportedOperationException()

  private fun providerContext(): Context =
    context ?: throw FileNotFoundException("No context")

  private fun idOf(uri: Uri): String = uri.lastPathSegment ?: ""

  companion object {
    private val blobs = ConcurrentHashMap<String, Blob>()

    fun authority(context: Context): String = "${context.packageName}.ghostblob"

    /** Keeps [bytes] in memory and returns the uri another app may read. */
    fun put(context: Context, bytes: ByteArray, name: String, mime: String): Uri {
      val id = UUID.randomUUID().toString()
      blobs[id] = Blob(bytes, name, mime)
      return Uri.parse("content://${authority(context)}/blob/$id")
    }

    /**
     * A seekable, RAM-backed descriptor over a blob, for this process's own
     * readers ([GhostPdfDocuments]). Null below API 26, where only a pipe
     * exists and a PDF renderer cannot use one.
     */
    fun readDescriptor(context: Context, uri: Uri): ParcelFileDescriptor? {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
      val blob = blobs[uri.lastPathSegment ?: ""] ?: return null
      return seekableDescriptor(context, blob.bytes)
    }

    /**
     * Overwrites and forgets the named blobs only. A locked chat releases its
     * files this way when it locks again, without touching a Ghost session.
     */
    fun drop(uris: List<String>) {
      uris.forEach { uri ->
        blobs.remove(Uri.parse(uri).lastPathSegment ?: "")?.bytes?.fill(0)
      }
    }

    /** The burn: overwrite every array, then forget it. */
    fun clear() {
      val held = blobs.values.toList()
      blobs.clear()
      held.forEach { it.bytes.fill(0) }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.O)
    private fun seekableDescriptor(context: Context, bytes: ByteArray): ParcelFileDescriptor {
      val storage = context.getSystemService(StorageManager::class.java)
        ?: return pipeDescriptor(bytes)
      val thread = HandlerThread("ghost-blob").apply { start() }
      return storage.openProxyFileDescriptor(
        ParcelFileDescriptor.MODE_READ_ONLY,
        object : ProxyFileDescriptorCallback() {
          override fun onGetSize(): Long = bytes.size.toLong()

          override fun onRead(offset: Long, size: Int, data: ByteArray): Int {
            if (offset >= bytes.size) return 0
            val count = minOf(size.toLong(), bytes.size - offset).toInt()
            System.arraycopy(bytes, offset.toInt(), data, 0, count)
            return count
          }

          override fun onFsync() = throw ErrnoException("onFsync", OsConstants.EBADF)

          override fun onRelease() {
            thread.quitSafely()
          }
        },
        Handler(thread.looper),
      )
    }

    /** Pre-26 fallback: readable start to finish, but not seekable. */
    private fun pipeDescriptor(bytes: ByteArray): ParcelFileDescriptor {
      val pipe = ParcelFileDescriptor.createPipe()
      Thread {
        try {
          ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { it.write(bytes) }
        } catch (_: Exception) {
          // The reader went away; nothing to recover.
        }
      }.start()
      return pipe[0]
    }
  }
}
