package com.ababilx.app.mediasend.review

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import com.ababilx.app.R
import com.ababilx.app.mediasend.MediaQuality
import com.ababilx.app.mediasend.MediaSendInsets

/**
 * Signal's "Media quality" sheet: Standard or High, one tap, sheet closes.
 *
 * It carries no state of its own beyond what is highlighted — [ReviewView]
 * owns the chosen level, because that level has to survive the sheet being
 * dismissed and has to be handed back to Dart on send.
 */
class QualitySheetView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    var onPicked: ((MediaQuality) -> Unit)? = null

    private val standard: View
    private val high: View

    init {
        LayoutInflater.from(context).inflate(R.layout.media_send_quality_sheet, this, true)
        standard = findViewById(R.id.quality_standard)
        high = findViewById(R.id.quality_high)

        standard.setOnClickListener { pick(MediaQuality.STANDARD) }
        high.setOnClickListener { pick(MediaQuality.HIGH) }
        // Tapping the scrim dismisses, the way a real bottom sheet does. The
        // panel swallows its own taps so a miss inside it does not close.
        findViewById<View>(R.id.quality_scrim).setOnClickListener { hide() }
        findViewById<View>(R.id.quality_panel).setOnClickListener { }

        MediaSendInsets.padBottom(findViewById(R.id.quality_panel))
    }

    fun show(current: MediaQuality) {
        standard.isSelected = current == MediaQuality.STANDARD
        high.isSelected = current == MediaQuality.HIGH
        visibility = View.VISIBLE
    }

    fun hide() {
        visibility = View.GONE
    }

    val isShowing: Boolean get() = visibility == View.VISIBLE

    private fun pick(quality: MediaQuality) {
        hide()
        onPicked?.invoke(quality)
    }
}
