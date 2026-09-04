package com.ababilx.app.mediasend.review

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import com.ababilx.app.R
import com.ababilx.app.mediasend.MediaSendInsets

/**
 * What "+ Add more" opens: Camera, Gallery or Files.
 *
 * `+` used to drop straight into the library grid, which made the other two
 * ways of adding something reachable only from inside it. All three are one
 * tap now, and the grid is a destination rather than a corridor.
 */
class AddMoreSheetView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    var onCamera: (() -> Unit)? = null
    var onGallery: (() -> Unit)? = null
    var onFiles: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.media_send_add_sheet, this, true)
        findViewById<View>(R.id.add_camera).setOnClickListener { pick(onCamera) }
        findViewById<View>(R.id.add_gallery).setOnClickListener { pick(onGallery) }
        findViewById<View>(R.id.add_files).setOnClickListener { pick(onFiles) }
        // Tapping the scrim dismisses, the way a real bottom sheet does; the
        // panel swallows its own taps so a miss inside it does not close.
        findViewById<View>(R.id.add_scrim).setOnClickListener { hide() }
        findViewById<View>(R.id.add_panel).setOnClickListener { }

        MediaSendInsets.padBottom(findViewById(R.id.add_panel))
    }

    fun show() {
        visibility = View.VISIBLE
    }

    fun hide() {
        visibility = View.GONE
    }

    val isShowing: Boolean get() = visibility == View.VISIBLE

    private fun pick(action: (() -> Unit)?) {
        hide()
        action?.invoke()
    }
}
