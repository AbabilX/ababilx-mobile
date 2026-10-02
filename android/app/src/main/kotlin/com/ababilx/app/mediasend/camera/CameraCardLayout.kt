package com.ababilx.app.mediasend.camera

import android.view.View
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import kotlin.math.roundToInt

/**
 * Where the viewfinder card goes, which depends on the window's shape —
 * Signal's `CameraDisplay`, reduced to the three cases a phone can be in.
 *
 * ```
 * tall (19.5:9, 20:9)   full-width 9:16 card, bottom edge on the mode bar,
 *                       the bar under it, 20 dp above the navigation bar
 * medium                9:16 card fills between the bars; the mode bar and
 *                       the controls sit over its lower edge
 * short / wide          the same, narrowed to keep 9:16
 * ```
 *
 * The card is always 9:16 because the camera is bound at 16:9: what the
 * viewfinder shows is exactly the photo that will arrive in review.
 */
object CameraCardLayout {

    private const val BAR_DP = 44
    private const val BAR_GAP_DP = 20
    private const val CONTROLS_DP = 54
    private const val ZOOM_DP = 146

    /**
     * Lays the screen out now and again whenever the window's insets or the
     * screen's size change. The screen draws edge to edge, so the insets are
     * read here rather than padded for us.
     */
    fun install(root: View, card: View, modes: View, controls: View, zoom: View) {
        var top = 0
        var bottom = 0
        val relayout = Runnable { apply(root, card, modes, controls, zoom, top, bottom) }
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
            )
            top = bars.top
            bottom = bars.bottom
            root.post(relayout)
            insets
        }
        root.addOnLayoutChangeListener { _, left, top2, right, bottom2, oldLeft, oldTop, oldRight, oldBottom ->
            val resized = right - left != oldRight - oldLeft || bottom2 - top2 != oldBottom - oldTop
            if (resized) root.post(relayout)
        }
    }

    private fun apply(
        root: View,
        card: View,
        modes: View,
        controls: View,
        zoom: View,
        topInset: Int,
        bottomInset: Int,
    ) {
        val width = root.width
        val height = root.height
        if (width == 0 || height == 0) return
        val density = root.resources.displayMetrics.density
        val barArea = ((BAR_DP + BAR_GAP_DP) * density).roundToInt()
        val full = width * 16 / 9

        val cardWidth: Int
        val cardHeight: Int
        val cardBottom: Int
        val lift: Int
        when {
            full <= height - topInset - bottomInset - barArea -> {
                cardWidth = width
                cardHeight = full
                cardBottom = bottomInset + barArea
                lift = 0
            }
            full <= height - topInset - bottomInset -> {
                cardWidth = width
                cardHeight = full
                cardBottom = bottomInset
                lift = barArea
            }
            else -> {
                cardHeight = height - topInset - bottomInset
                cardWidth = cardHeight * 9 / 16
                cardBottom = bottomInset
                lift = barArea
            }
        }

        card.layoutParams = (card.layoutParams as FrameLayout.LayoutParams).apply {
            this.width = cardWidth
            this.height = cardHeight
            gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL
            bottomMargin = cardBottom
        }
        modes.layoutParams = (modes.layoutParams as FrameLayout.LayoutParams).apply {
            bottomMargin = bottomInset + (BAR_GAP_DP * density).roundToInt()
        }
        controls.layoutParams = (controls.layoutParams as FrameLayout.LayoutParams).apply {
            bottomMargin = (CONTROLS_DP * density).roundToInt() + lift
        }
        zoom.layoutParams = (zoom.layoutParams as FrameLayout.LayoutParams).apply {
            bottomMargin = (ZOOM_DP * density).roundToInt() + lift
        }
    }
}
