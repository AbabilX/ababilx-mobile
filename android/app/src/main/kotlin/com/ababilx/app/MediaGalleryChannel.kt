package com.ababilx.app

import android.app.Activity
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * The in-app media grid's data source.
 *
 * Everything here runs off the main thread — a cursor over a large library and
 * a JPEG decode both take long enough to drop frames, and Signal's grid feels
 * instant precisely because neither happens on the UI thread.
 *
 * Runtime permission is requested from Dart (`permission_handler`) rather than
 * here: the app already owns a permission flow, and duplicating it in Kotlin
 * would mean two places deciding what to do when the user says no.
 */
class MediaGalleryChannel(private val activity: Activity) {

    private var channel: MethodChannel? = null
    private val io = Executors.newFixedThreadPool(3)

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(hasAccess())
                    "list" -> background(result) {
                        MediaGalleryQuery.page(
                            activity,
                            call.argument<Int>("offset") ?: 0,
                            call.argument<Int>("limit") ?: 60,
                            call.argument<String>("kind") ?: "all",
                        )
                    }
                    "thumbnail" -> background(result) {
                        val uri = call.argument<String>("uri")
                        val maxPx = call.argument<Int>("maxPx") ?: 256
                        if (uri == null) null else ShareThumbnails.of(activity, uri, maxPx)
                    }
                    "copyToCache" -> background(result) {
                        val uri = call.argument<String>("uri")
                        val name = call.argument<String>("name") ?: "media"
                        if (uri == null) null else copyToCache(uri, name)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        io.shutdown()
    }

    /**
     * Whether the library is readable at all. On Android 14 a "Select photos"
     * partial grant counts as access: the query then returns just the chosen
     * items, which is a smaller grid rather than a broken one.
     */
    private fun hasAccess(): Boolean {
        val needed = when {
            Build.VERSION.SDK_INT >= 34 -> listOf(
                "android.permission.READ_MEDIA_IMAGES",
                "android.permission.READ_MEDIA_VIDEO",
                "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
            )
            Build.VERSION.SDK_INT >= 33 -> listOf(
                "android.permission.READ_MEDIA_IMAGES",
                "android.permission.READ_MEDIA_VIDEO",
            )
            else -> listOf("android.permission.READ_EXTERNAL_STORAGE")
        }
        return needed.any {
            activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * A real file for the picked item, because the upload path deals in bytes
     * and a `content://` URI is not readable once the grant is gone.
     */
    private fun copyToCache(uriString: String, name: String): String? = try {
        val uri = Uri.parse(uriString)
        val dir = File(activity.cacheDir, "picked").apply { mkdirs() }
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_").takeLast(80)
        val target = File(dir, "${System.currentTimeMillis()}-$safe")
        activity.contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { input.copyTo(it) }
        }
        if (target.length() > 0) target.absolutePath else null
    } catch (error: Exception) {
        Log.w(TAG, "copyToCache failed", error)
        null
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try {
                work()
            } catch (error: Exception) {
                Log.w(TAG, "gallery work failed", error)
                null
            }
            activity.runOnUiThread { result.success(value) }
        }
    }

    private companion object {
        const val TAG = "MediaGalleryChannel"
        const val CHANNEL = "com.ababilx.app/media_gallery"
    }
}
