package com.ababilx.app.mediasend

import android.content.Intent

/**
 * What the caller asked the flow for, read off the Intent once.
 *
 * [start] is the front door: the library grid, the camera, the document
 * picker, or the review screen itself over URIs the caller already holds (how
 * a share from another app reaches the same edit tools). Everything but the
 * grid has nothing behind it, which is why [startsAtGallery] decides whether
 * backing out of the review screen goes anywhere or ends the flow.
 */
class MediaSendRequest(
    val maxSelection: Int,
    val allowVideo: Boolean,
    val start: String,
    val quality: MediaQuality,
    val uris: List<String>,
    val names: List<String>,
    val mimes: List<String>,
    val caption: String,
    /** Whether the review screen may offer view once (a DM with someone else). */
    val allowViewOnce: Boolean,
) {
    val startsAtGallery: Boolean get() = start == START_GALLERY

    companion object {
        const val EXTRA_MAX = "max_selection"
        const val EXTRA_ALLOW_VIDEO = "allow_video"
        const val EXTRA_START = "start"
        const val EXTRA_QUALITY = "quality"
        const val EXTRA_URIS = "uris"
        const val EXTRA_NAMES = "names"
        const val EXTRA_MIMES = "mimes"
        const val EXTRA_CAPTION = "caption"
        const val EXTRA_ALLOW_VIEW_ONCE = "allow_view_once"

        const val START_GALLERY = "gallery"
        const val START_CAMERA = "camera"
        const val START_FILES = "files"
        const val START_REVIEW = "review"

        fun from(intent: Intent) = MediaSendRequest(
            maxSelection = intent.getIntExtra(EXTRA_MAX, 10),
            allowVideo = intent.getBooleanExtra(EXTRA_ALLOW_VIDEO, true),
            start = intent.getStringExtra(EXTRA_START) ?: START_GALLERY,
            quality = MediaQuality.fromCode(
                intent.getIntExtra(EXTRA_QUALITY, MediaQuality.STANDARD.code),
            ),
            uris = intent.getStringArrayListExtra(EXTRA_URIS).orEmpty(),
            names = intent.getStringArrayListExtra(EXTRA_NAMES).orEmpty(),
            mimes = intent.getStringArrayListExtra(EXTRA_MIMES).orEmpty(),
            caption = intent.getStringExtra(EXTRA_CAPTION).orEmpty(),
            allowViewOnce = intent.getBooleanExtra(EXTRA_ALLOW_VIEW_ONCE, false),
        )
    }
}
