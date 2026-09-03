package com.ababilx.app.mediasend

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's door into the native flow.
 *
 * `open` starts [MediaSendActivity] and parks the pending result until the
 * Activity comes back — one call in, one list of files out. Nothing about the
 * grid, the review screen or the editor leaks across the channel, so the
 * Flutter composer stays exactly as simple as it was with the old sheet.
 */
class MediaSendChannel(private val activity: Activity) {

    private var channel: MethodChannel? = null
    private var pending: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(true)
                    "open" -> open(call.argument<Int>("maxSelection") ?: 10, call.argument<Boolean>("allowVideo") ?: true, result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        // A pending call whose Activity never returns would hang the composer.
        pending?.success(null)
        pending = null
    }

    /** @return true when this result belonged to the media-send flow. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        result.success(
            if (resultCode == Activity.RESULT_OK) MediaSendResult.toChannelPayload(data) else null,
        )
        return true
    }

    private fun open(maxSelection: Int, allowVideo: Boolean, result: MethodChannel.Result) {
        // A second open while one is up would strand the first call.
        pending?.success(null)
        pending = result
        activity.startActivityForResult(
            Intent(activity, MediaSendActivity::class.java)
                .putExtra(MediaSendActivity.EXTRA_MAX, maxSelection)
                .putExtra(MediaSendActivity.EXTRA_ALLOW_VIDEO, allowVideo),
            REQUEST_CODE,
        )
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/media_send"
        const val REQUEST_CODE = 4110
    }
}
