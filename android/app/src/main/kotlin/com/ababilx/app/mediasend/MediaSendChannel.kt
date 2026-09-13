package com.ababilx.app.mediasend

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
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
                    "open" -> open(
                        maxSelection = call.argument<Int>("maxSelection") ?: 10,
                        allowVideo = call.argument<Boolean>("allowVideo") ?: true,
                        start = call.argument<String>("start") ?: MediaSendRequest.START_GALLERY,
                        quality = call.argument<Int>("quality") ?: 0,
                        uris = call.argument<List<String>>("uris").orEmpty(),
                        names = call.argument<List<String>>("names").orEmpty(),
                        mimes = call.argument<List<String>>("mimes").orEmpty(),
                        caption = call.argument<String>("caption").orEmpty(),
                        result = result,
                    )
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

    private fun open(
        maxSelection: Int,
        allowVideo: Boolean,
        start: String,
        quality: Int,
        uris: List<String>,
        names: List<String>,
        mimes: List<String>,
        caption: String,
        result: MethodChannel.Result,
    ) {
        // A second open while one is up would strand the first call.
        pending?.success(null)
        pending = result
        val intent = Intent(activity, MediaSendActivity::class.java)
            .putExtra(MediaSendRequest.EXTRA_MAX, maxSelection)
            .putExtra(MediaSendRequest.EXTRA_ALLOW_VIDEO, allowVideo)
            .putExtra(MediaSendRequest.EXTRA_START, start)
            .putExtra(MediaSendRequest.EXTRA_QUALITY, quality)
            .putExtra(MediaSendRequest.EXTRA_CAPTION, caption)
        if (uris.isNotEmpty()) {
            intent
                .putStringArrayListExtra(MediaSendRequest.EXTRA_URIS, ArrayList(uris))
                .putStringArrayListExtra(MediaSendRequest.EXTRA_NAMES, ArrayList(names))
                .putStringArrayListExtra(MediaSendRequest.EXTRA_MIMES, ArrayList(mimes))
                // A share's read grant belongs to this package, but an
                // Activity started with the URI only in an extra is not
                // covered by it. ClipData plus the flag carries the grant
                // across; without it a shared photo opens as a blank page.
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .also { it.clipData = clipFor(uris) }
        }
        activity.startActivityForResult(intent, REQUEST_CODE)
    }

    private fun clipFor(uris: List<String>): ClipData? {
        val parsed = uris.mapNotNull { runCatching { Uri.parse(it) }.getOrNull() }
        val first = parsed.firstOrNull() ?: return null
        return ClipData("media", arrayOf("*/*"), ClipData.Item(first)).apply {
            for (uri in parsed.drop(1)) addItem(ClipData.Item(uri))
        }
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/media_send"
        const val REQUEST_CODE = 4110
    }
}
