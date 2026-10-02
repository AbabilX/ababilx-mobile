package com.ababilx.app.mediasend.camera

import android.content.Context
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.ababilx.app.R
import kotlin.math.abs

/**
 * Signal's zoom bar: one tap straight to .5 / 1 / 2 / 5.
 *
 * Only the levels the lens can actually reach are offered — a level the
 * camera would clamp away from is a tap that lands somewhere else — and a
 * single level is nothing to switch between, so then the bar hides. The
 * selection follows wherever the camera really is, so a pinch or a drag along
 * the capture button lights the level it passes through and none in between.
 * "Near" is 2 % of the level, which absorbs a fused ultra-wide that reaches
 * 0.506 rather than a round half.
 */
class ZoomBar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : LinearLayout(context, attrs) {

    var onLevel: (Float) -> Unit = {}

    private val density = resources.displayMetrics.density
    private var levels: List<Float> = emptyList()
    private var cells: List<TextView> = emptyList()
    private var range: ClosedFloatingPointRange<Float> = 1f..1f

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setBackgroundResource(R.drawable.ms_camera_pill)
        visibility = GONE
    }

    /** The camera's current zoom and reach, as CameraX reports it. */
    fun update(ratio: Float, reach: ClosedFloatingPointRange<Float>) {
        if (reach != range) {
            range = reach
            rebuild(LEVELS.filter { isAt(it.coerceIn(reach), it) })
        }
        for ((index, level) in levels.withIndex()) {
            val selected = isAt(ratio, level)
            cells[index].isSelected = selected
            cells[index].setBackgroundResource(if (selected) R.drawable.ms_camera_zoom_selected else 0)
        }
    }

    /** Turn the numbers so they read upright; the bar itself stays put. */
    fun rotateLabels(degrees: Float) {
        for (cell in cells) cell.animate().rotation(degrees).setDuration(ROTATE_MS).start()
    }

    private fun rebuild(next: List<Float>) {
        removeAllViews()
        levels = next
        val px = (LEVEL_DP * density).toInt()
        cells = next.map { level ->
            TextView(context).apply {
                text = label(level)
                gravity = Gravity.CENTER
                setTextColor(context.getColor(R.color.media_send_on_dark))
                textSize = 14f
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                includeFontPadding = false
                contentDescription = context.getString(R.string.media_send_zoom_level, label(level))
                setOnClickListener { onLevel(level) }
                this@ZoomBar.addView(this, LayoutParams(px, px))
            }
        }
        visibility = if (next.size >= 2) VISIBLE else GONE
    }

    private fun label(level: Float) = if (level < 1f) ".5" else level.toInt().toString()

    private fun isAt(ratio: Float, level: Float) = abs(ratio - level) <= level * TOLERANCE

    private companion object {
        val LEVELS = listOf(0.5f, 1f, 2f, 5f)
        const val TOLERANCE = 0.02f
        const val LEVEL_DP = 40f
        const val ROTATE_MS = 200L
    }
}
