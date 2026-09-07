package com.ababilx.app.mediasend

import android.content.res.Resources

/**
 * How large the review pager and the editor decode a picture.
 *
 * Capped at the screen's longest edge, because decoding beyond what the
 * display can show buys nothing: the editor stores its strokes normalised and
 * `MediaSendExport` re-decodes at the quality level's own target, so preview
 * resolution never reaches the exported file. A short or low-resolution phone
 * therefore pays less — which is the device that could least afford a 12 MP
 * decode in the first place.
 */
object MediaSendPreview {

    /** Signal's own review size, and the ceiling here. */
    private const val MAX_PX = 1600

    fun sizeFor(resources: Resources): Int {
        val metrics = resources.displayMetrics
        return minOf(MAX_PX, maxOf(metrics.widthPixels, metrics.heightPixels))
    }
}
