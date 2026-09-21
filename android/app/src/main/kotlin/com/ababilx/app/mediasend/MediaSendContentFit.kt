package com.ababilx.app.mediasend

import android.view.View
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Keeps the picture in the space BETWEEN the top and bottom chrome.
 *
 * The bars used to float over a full-screen picture, so a tall photo ran
 * under the close/done row and under the tool row — a stroke drawn there
 * landed behind a button. The picture's view now takes margins equal to the
 * bars' measured heights (status bar and navigation bar included, since
 * [MediaSendInsets] pads the bars), and the image fits inside that box.
 *
 * The keyboard is deliberately NOT followed: it covers the picture anyway,
 * and shrinking the box for it would make the photo jump while typing a
 * caption. While it is up the previous bottom margin stays.
 */
object MediaSendContentFit {

    /** Pads both bars for the system insets and fits [content] between them. */
    fun chrome(root: View, content: View, topId: Int, bottomId: Int) {
        val top = root.findViewById<View>(topId)
        val bottom = root.findViewById<View>(bottomId)
        MediaSendInsets.padTop(top)
        MediaSendInsets.padBottom(bottom)
        between(content, top, bottom)
    }

    fun between(content: View, top: View, bottom: View) {
        val update = View.OnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            val imeUp = ViewCompat.getRootWindowInsets(bottom)
                ?.isVisible(WindowInsetsCompat.Type.ime()) == true
            val params = content.layoutParams as? FrameLayout.LayoutParams
                ?: return@OnLayoutChangeListener
            val nextTop = top.height
            val nextBottom = if (imeUp) params.bottomMargin else bottom.height
            if (params.topMargin == nextTop && params.bottomMargin == nextBottom) {
                return@OnLayoutChangeListener
            }
            // Posted: changing layout params inside a layout pass is dropped.
            content.post {
                params.topMargin = nextTop
                params.bottomMargin = nextBottom
                content.layoutParams = params
            }
        }
        top.addOnLayoutChangeListener(update)
        bottom.addOnLayoutChangeListener(update)
    }
}
