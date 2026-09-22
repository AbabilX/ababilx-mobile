package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Draws a Ghost Chat PDF inside the app without the file touching the disk.
 *
 * The receiver of a file the sender marked "no saving" may only look at it
 * here — handing it to a PDF app is handing that app a copy. pdfx cannot be
 * used for this: its `openData` writes the bytes to `cacheDir` as a plain
 * `.pdf` and never deletes it, and renders every page to an image file too.
 *
 * So Android's own [PdfRenderer] reads the blob through
 * [GhostBlobProvider.readDescriptor] (RAM-backed, seekable), and each page
 * comes back to Dart as PNG bytes in memory. One worker thread renders, since
 * a [PdfRenderer] allows one open page at a time; the results are delivered
 * on the main thread, as a MethodChannel reply must be.
 */
class GhostPdfDocuments {

  private class Doc(val renderer: PdfRenderer, val fd: ParcelFileDescriptor)

  private val docs = ConcurrentHashMap<String, Doc>()
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  fun open(context: Context, uri: String?, result: MethodChannel.Result) {
    if (uri.isNullOrEmpty()) return result.success(null)
    val app = context.applicationContext
    worker.execute {
      val reply: Map<String, Any>? = try {
        val fd = GhostBlobProvider.readDescriptor(app, Uri.parse(uri))
        if (fd == null) {
          null
        } else {
          val id = UUID.randomUUID().toString()
          val renderer = PdfRenderer(fd)
          docs[id] = Doc(renderer, fd)
          mapOf("id" to id, "pages" to renderer.pageCount)
        }
      } catch (_: Exception) {
        null
      }
      main.post { result.success(reply) }
    }
  }

  fun page(id: String?, index: Int, width: Int, result: MethodChannel.Result) {
    worker.execute {
      val png: ByteArray? = try {
        docs[id ?: ""]?.let { render(it.renderer, index, width.coerceIn(200, 2400)) }
      } catch (_: Exception) {
        null
      }
      main.post { result.success(png) }
    }
  }

  fun close(id: String?) {
    val doc = docs.remove(id ?: "") ?: return
    worker.execute { release(doc) }
  }

  /** The burn. Queued behind any render in flight, which then finds nothing. */
  fun closeAll() {
    val held = docs.values.toList()
    docs.clear()
    worker.execute { held.forEach(::release) }
  }

  private fun render(renderer: PdfRenderer, index: Int, width: Int): ByteArray? {
    if (index !in 0 until renderer.pageCount) return null
    renderer.openPage(index).use { page ->
      val height = (width.toLong() * page.height / page.width).toInt().coerceAtLeast(1)
      val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      try {
        bitmap.eraseColor(Color.WHITE)
        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
        return ByteArrayOutputStream().use { out ->
          bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
          out.toByteArray()
        }
      } finally {
        bitmap.recycle()
      }
    }
  }

  companion object {
    val shared = GhostPdfDocuments()
  }

  private fun release(doc: Doc) {
    try {
      doc.renderer.close()
    } catch (_: Exception) {
    }
    try {
      doc.fd.close()
    } catch (_: Exception) {
    }
  }
}
