package com.ababilx.app.mediasend

import android.view.View
import android.view.ViewGroup
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.ababilx.app.R

/**
 * Keeps the flow's top and bottom chrome clear of the status bar, the
 * gesture/navigation bar, a display cutout and the keyboard.
 *
 * The Activity draws edge-to-edge (Android 15's default, and true on every
 * version once [MediaSendActivity] asks for it), so nothing pads the content
 * automatically — the review rail and its Send button rendered *under* the
 * navigation bar until this ran.
 *
 * There is exactly **one** listener, on the Activity's root, and it walks down
 * to the bars that marked themselves. Per-bar listeners were the obvious
 * shape and the wrong one: a bar only hears about insets if every ancestor
 * dispatches them down, and the three screens are siblings that spend most of
 * their life `GONE`, are inflated from `<merge>` blocks, and mark themselves
 * during `setContentView` — before anything is attached to a window, so the
 * `requestApplyInsets` that follows a mark is a no-op. Walking from the root
 * on every dispatch depends on none of that.
 *
 * This pads rather than insetting with a margin: the bar's own background
 * (`media_send_scrim`, `media_send_chrome`) still has to reach the physical
 * edge — only its contents should not.
 */
object MediaSendInsets {

    private const val TOP = 1
    private const val BOTTOM = 2

    /** Mark a bar that sits under the status bar / cutout. */
    fun padTop(view: View) = mark(view, TOP)

    /** Mark a bar that sits over the navigation bar / keyboard. */
    fun padBottom(view: View) = mark(view, BOTTOM)

    /** Call once on the Activity's root, after the marked bars are inflated. */
    fun install(root: View) {
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, windowInsets ->
            apply(
                view,
                windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() or
                        WindowInsetsCompat.Type.displayCutout() or
                        WindowInsetsCompat.Type.ime(),
                ),
            )
            // Handed on unconsumed: the grid and the pager still want to know.
            windowInsets
        }
        ViewCompat.requestApplyInsets(root)
    }

    /**
     * Stashes the edge plus the padding the layout asked for, so a later
     * dispatch (rotation, keyboard, cutout change) adds to *that* rather than
     * compounding on its own last output.
     */
    private fun mark(view: View, edge: Int) {
        view.setTag(
            R.id.media_send_base_padding,
            intArrayOf(
                edge,
                view.paddingLeft,
                view.paddingTop,
                view.paddingRight,
                view.paddingBottom,
            ),
        )
    }

    private fun apply(view: View, bars: Insets) {
        (view.getTag(R.id.media_send_base_padding) as? IntArray)?.let { base ->
            view.setPadding(
                base[1] + bars.left,
                base[2] + if (base[0] == TOP) bars.top else 0,
                base[3] + bars.right,
                base[4] + if (base[0] == BOTTOM) bars.bottom else 0,
            )
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) apply(view.getChildAt(i), bars)
        }
    }
}
