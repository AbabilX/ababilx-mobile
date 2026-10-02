package com.ababilx.app.mediasend.camera

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.TextView
import com.ababilx.app.R
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Signal's Video | Photo switch under the viewfinder.
 *
 * The highlight never moves: it is pinned to the middle of the screen and the
 * BAR slides underneath it until the chosen mode sits in it. A mode is picked
 * by tapping it or by swiping the bar, and a swipe only commits on release,
 * so the user can slide back and forth first. 44 dp tall, 6 dp inset, each
 * mode at least 80 dp wide — Signal's numbers.
 */
class CaptureModeBar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : ViewGroup(context, attrs) {

    var onMode: (CaptureMode) -> Unit = {}

    var mode: CaptureMode = CaptureMode.PHOTO
        private set

    private val modes = listOf(CaptureMode.VIDEO, CaptureMode.PHOTO)
    private val density = resources.displayMetrics.density
    private val barHeight = (44 * density).roundToInt()
    private val inset = (6 * density).roundToInt()
    private val minMode = (80 * density).roundToInt()
    private val textPad = (20 * density).roundToInt()

    private val bar = View(context).apply { setBackgroundResource(R.drawable.ms_camera_pill) }
    private val highlight = View(context).apply { setBackgroundResource(R.drawable.ms_camera_mode_selected) }
    private val labels = modes.map { option ->
        TextView(context).apply {
            setText(if (option == CaptureMode.VIDEO) R.string.media_send_mode_video else R.string.media_send_mode_photo)
            gravity = Gravity.CENTER
            maxLines = 1
            setTextColor(context.getColor(R.color.media_send_on_dark))
            textSize = 15f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            includeFontPadding = false
            setOnClickListener { select(option, notify = true) }
        }
    }

    /** Which mode is under the highlight, fractional while sliding. */
    private var centered = modes.indexOf(mode).toFloat()
    private var modeWidth = minMode
    private var animator: ValueAnimator? = null
    private var downX = 0f
    private var dragging = false

    init {
        addView(bar)
        addView(highlight)
        labels.forEach(::addView)
    }

    fun select(value: CaptureMode, notify: Boolean = false) {
        val changed = value != mode
        mode = value
        labels.forEachIndexed { i, label -> label.isSelected = modes[i] == value }
        settle(modes.indexOf(value).toFloat())
        if (changed && notify) onMode(value)
    }

    private fun settle(to: Float) {
        animator?.cancel()
        animator = ValueAnimator.ofFloat(centered, to).apply {
            duration = SETTLE_MS
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                centered = it.animatedValue as Float
                requestLayout()
            }
            start()
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val exact = MeasureSpec.makeMeasureSpec(barHeight - inset * 2, MeasureSpec.EXACTLY)
        var widest = minMode
        for (label in labels) {
            label.measure(MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED), exact)
            widest = max(widest, label.measuredWidth + textPad * 2)
        }
        modeWidth = widest
        labels.forEach { it.measure(MeasureSpec.makeMeasureSpec(modeWidth, MeasureSpec.EXACTLY), exact) }
        highlight.measure(MeasureSpec.makeMeasureSpec(modeWidth, MeasureSpec.EXACTLY), exact)
        bar.measure(
            MeasureSpec.makeMeasureSpec(modeWidth * modes.size + inset * 2, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(barHeight, MeasureSpec.EXACTLY),
        )
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), barHeight)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val row = r - l
        val slide = (row / 2f - inset - (centered + 0.5f) * modeWidth).roundToInt()
        bar.layout(slide, 0, slide + bar.measuredWidth, barHeight)
        val hx = (row - modeWidth) / 2
        highlight.layout(hx, inset, hx + modeWidth, barHeight - inset)
        labels.forEachIndexed { i, label ->
            val x = slide + inset + i * modeWidth
            label.layout(x, inset, x + modeWidth, barHeight - inset)
        }
    }

    /** Only the bar itself takes touches; the empty row beside it stays see-through. */
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN &&
            (event.x < bar.left || event.x > bar.right)
        ) {
            return false
        }
        return super.dispatchTouchEvent(event)
    }

    override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.x
                dragging = false
            }
            MotionEvent.ACTION_MOVE -> if (abs(event.x - downX) > SLOP_DP * density) dragging = true
        }
        return dragging
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> downX = event.x
            MotionEvent.ACTION_MOVE -> {
                animator?.cancel()
                val slid = -(event.x - downX) / modeWidth
                downX = event.x
                centered = (centered + slid).coerceIn(0f, (modes.size - 1).toFloat())
                requestLayout()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                dragging = false
                select(modes[centered.roundToInt().coerceIn(modes.indices)], notify = true)
            }
        }
        return true
    }

    private companion object {
        const val SETTLE_MS = 220L
        const val SLOP_DP = 8f
    }
}
