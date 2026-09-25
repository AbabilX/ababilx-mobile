package com.ababilx.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's door to [GhostBlobProvider]: hold a Ghost Chat file in memory, open
 * it in another app, and wipe everything on the burn.
 *
 * The chooser carries `FLAG_GRANT_READ_URI_PERMISSION`, so the viewer the user
 * picks — and only that one, only for this launch — may read the blob. The
 * provider itself is not exported, so nothing else on the phone can ask for it.
 */
class GhostBlobChannel(private val activity: Activity) {

  // One per process, like the blobs: an Activity recreated mid-session must
  // still close the documents the previous one opened.
  private val pdfs = GhostPdfDocuments.shared

  fun attach(engine: FlutterEngine) {
    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "put" -> {
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null) {
              result.error("invalid", "bytes missing", null)
            } else {
              val uri = GhostBlobProvider.put(
                activity,
                bytes,
                call.argument<String>("name") ?: "file",
                call.argument<String>("mime") ?: "application/octet-stream",
              )
              result.success(uri.toString())
            }
          }
          "open" -> result.success(open(call.argument<String>("uri"), call.argument<String>("mime")))
          "pdfOpen" -> pdfs.open(activity, call.argument<String>("uri"), result)
          "pdfPage" -> pdfs.page(
            call.argument<String>("id"),
            call.argument<Int>("index") ?: 0,
            call.argument<Int>("width") ?: 1080,
            result,
          )
          "pdfClose" -> {
            pdfs.close(call.argument<String>("id"))
            result.success(null)
          }
          "drop" -> {
            GhostBlobProvider.drop(call.argument<List<String>>("uris") ?: emptyList())
            result.success(null)
          }
          "clear" -> {
            pdfs.closeAll()
            GhostBlobProvider.clear()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun open(uri: String?, mime: String?): Boolean {
    if (uri.isNullOrEmpty()) return false
    val view = Intent(Intent.ACTION_VIEW).apply {
      setDataAndType(android.net.Uri.parse(uri), mime ?: "*/*")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return try {
      activity.startActivity(Intent.createChooser(view, null).apply {
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      })
      true
    } catch (_: ActivityNotFoundException) {
      false
    }
  }

  private companion object {
    const val CHANNEL = "com.ababilx.app/ghost_blob"
  }
}
