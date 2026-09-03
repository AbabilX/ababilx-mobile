package com.ababilx.app.mediasend

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.util.Log
import com.ababilx.app.mediasend.editor.EditRender
import java.io.File

/**
 * Turns the review screen's model into files the Dart uploader can read.
 *
 * An untouched item is *copied*, never re-encoded: sending a photo through the
 * flow without editing it must not cost a generation of JPEG quality, and a
 * video is never decoded at all. Only an item with edits is flattened, once,
 * here.
 */
object MediaSendExport {

    private const val TAG = "MediaSendExport"
    private const val EXPORT_MAX_PX = 3000
    private const val JPEG_QUALITY = 92

    class Output(
        val path: String,
        val name: String,
        val mime: String,
        val sizeBytes: Long,
    )

    fun export(context: Context, item: PickedItem): Output? =
        if (item.edited && !item.isVideo) flatten(context, item) else copy(context, item)

    private fun flatten(context: Context, item: PickedItem): Output? = try {
        val source = MediaBitmaps.decode(context, item.uri, EXPORT_MAX_PX)
        if (source == null) {
            copy(context, item)
        } else {
            val rendered = EditRender.export(source, item)
            val target = cacheFile(context, jpegName(item.name))
            target.outputStream().use {
                rendered.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it)
            }
            rendered.recycle()
            source.recycle()
            Output(target.absolutePath, jpegName(item.name), "image/jpeg", target.length())
        }
    } catch (error: Exception) {
        Log.w(TAG, "flatten failed", error)
        copy(context, item)
    } catch (_: OutOfMemoryError) {
        copy(context, item)
    }

    private fun copy(context: Context, item: PickedItem): Output? = try {
        val target = cacheFile(context, item.name)
        context.contentResolver.openInputStream(item.uri)?.use { input ->
            target.outputStream().use { input.copyTo(it) }
        }
        if (target.length() > 0) {
            Output(target.absolutePath, item.name, item.mime, target.length())
        } else {
            null
        }
    } catch (error: Exception) {
        Log.w(TAG, "copy failed", error)
        null
    }

    fun cacheFile(context: Context, name: String): File {
        val dir = File(context.cacheDir, "mediasend").apply { mkdirs() }
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_").takeLast(80)
        return File(dir, "${System.currentTimeMillis()}-$safe")
    }

    /** A rendered edit is always a JPEG, whatever the original was. */
    private fun jpegName(name: String): String {
        val base = name.substringBeforeLast('.', name)
        return "$base.jpg"
    }

    fun displayName(context: Context, uri: Uri, fallback: String): String = try {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) ?: fallback else fallback
        } ?: fallback
    } catch (_: Exception) {
        fallback
    }
}
