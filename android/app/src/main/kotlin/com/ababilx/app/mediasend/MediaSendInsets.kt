package com.ababilx.app.mediasend

import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.ababilx.app.R

/**
 * Keeps the flow's top and bottom chrome clear of the status bar and the
 * gesture/navigation bar.
 *
 * The Activity draws edge-to-edge (Android 15's default, and true on every
 * version once [MediaSendActivity] requests it), so nothing pads the content
 * automatically — the review rail and its Send button rendered *under* the
 * navigation bar until this ran. This pads rather than insetting with a
 * margin: the bar's own background (`media_send_scrim`, `media_send_chrome`)
 * still has to reach the physical edge, only its content inside it should not.
 */
object MediaSendInsets {

    /** Adds the status-bar inset to the view's existing top padding. */
    fun padTop(view: View) = listen(view, top = true)

    /** Adds the taller of the navigation-bar and IME inset to the bottom. */
    fun padBottom(view: View) = listen(view, top = false)

    private fun listen(view: View, top: Boolean) {
        // Stashed once so a later insets dispatch (rotation, keyboard) adds
        // to the *original* padding instead of compounding on its own output.
        view.setTag(
            R.id.media_send_base_padding,
            intArrayOf(view.paddingTop, view.paddingBottom),
        )
        ViewCompat.setOnApplyWindowInsetsListener(view) { v, windowInsets ->
            val bars = windowInsets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.ime(),
            )
            val base = v.getTag(R.id.media_send_base_padding) as IntArray
            v.setPadding(
                v.paddingLeft,
                if (top) base[0] + bars.top else v.paddingTop,
                v.paddingRight,
                if (!top) base[1] + bars.bottom else v.paddingBottom,
            )
            windowInsets
        }
        ViewCompat.requestApplyInsets(view)
    }
}
