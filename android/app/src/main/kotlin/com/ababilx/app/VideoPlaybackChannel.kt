package com.ababilx.app

import android.app.Activity
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * What video playback needs from the platform: a poster frame, and a screen
 * that stays awake while something is playing.
 *
 * Both are Android-only. iOS falls back to a live controller for the poster
 * (see `video_live_poster.dart`) and Flutter's own idle behaviour otherwise —
 * the Dart side asks and shrugs off a `MissingPluginException`.
 */
class VideoPlaybackChannel(private val activity: Activity) {

    private var channel: MethodChannel? = null
    private val io = Executors.newFixedThreadPool(2)

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "thumbnail" -> background(result) {
                        val path = call.argument<String>("path")
                        val maxPx = call.argument<Int>("maxPx") ?: 512
                        if (path.isNullOrEmpty()) null else VideoThumbnails.of(activity, path, maxPx)
                    }
                    "keepScreenOn" -> {
                        keepScreenOn(call.argument<Boolean>("on") == true)
                        result.success(null)
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
     * Held only while a video is actually playing. The flag lives on the
     * window, so it dies with the Activity even if a viewer is torn down
     * without saying so.
     */
    private fun keepScreenOn(on: Boolean) {
        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (on) activity.window.addFlags(flag) else activity.window.clearFlags(flag)
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try {
                work()
            } catch (error: Exception) {
                Log.w(TAG, "video work failed", error)
                null
            }
            activity.runOnUiThread { result.success(value) }
        }
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/video"
        const val TAG = "VideoChannel"
    }
}
