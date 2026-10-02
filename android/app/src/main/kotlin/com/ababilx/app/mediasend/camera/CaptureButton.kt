package com.ababilx.app.mediasend.camera

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.OvershootInterpolator
import com.ababilx.app.R

/**
 * Signal's capture button, drawn: a fixed 76 dp dark ring and an inner shape
 * that animates between the four things the button can be.
 *
 * ```
 * PHOTO             white circle 64      tap = photo, hold = held recording
 * VIDEO             red circle 64        tap = recording that runs unheld
 * RECORDING_HELD    red circle 56        lift = stop; drag up/down = zoom
 * RECORDING_LOCKED  red square 44 r10    tap = stop
 * ```
 *
 * Under a finger the idle shape shrinks to 56. Gestures are reported, never
 * acted on here: the screen decides what a tap means.
 */
class CaptureButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    enum class State { PHOTO, VIDEO, RECORDING_HELD, RECORDING_LOCKED }

    var onTap: () -> Unit = {}
    var onHoldStart: () -> Unit = {}
    var onHoldEnd: () -> Unit = {}

    /** Vertical travel since the hold began, in px; up is negative. */
    var onHoldDrag: (dy: Float) -> Unit = {}

    /** Whether a long press may start a recording from PHOTO. */
    var holdToRecord = true

    var state: State = State.PHOTO
        set(value) {
            if (field == value) return
            field = value
            animateTo(target(value))
        }

    private val density = resources.displayMetrics.density
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = context.getColor(R.color.media_send_camera_control)
    }
    private val innerPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val white = context.getColor(R.color.media_send_on_dark)
    private val red = context.getColor(R.color.media_send_camera_record)

    private var size = IDLE_DP * density
    private var radius = size / 2
    private var color = white
    private var animator: ValueAnimator? = null

    private var downY = 0f
    private var longPressFired = false
    private val longPress = Runnable {
        longPressFired = true
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        onHoldStart()
    }

    init {
        isClickable = true
        isFocusable = true
    }

    private class Shape(val size: Float, val radius: Float, val color: Int)

    private fun target(state: State, pressed: Boolean = false): Shape {
        val idle = (if (pressed) PRESSED_DP else IDLE_DP) * density
        return when (state) {
            State.PHOTO -> Shape(idle, idle / 2, white)
            State.VIDEO -> Shape(idle, idle / 2, red)
            State.RECORDING_HELD -> Shape(PRESSED_DP * density, PRESSED_DP * density / 2, red)
            State.RECORDING_LOCKED -> Shape(LOCKED_DP * density, LOCKED_RADIUS_DP * density, red)
        }
    }

    private fun animateTo(to: Shape) {
        animator?.cancel()
        val fromSize = size
        val fromRadius = radius
        val fromColor = color
        val evaluator = ArgbEvaluator()
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = ANIM_MS
            interpolator = OvershootInterpolator(1.4f)
            addUpdateListener {
                val t = it.animatedValue as Float
                size = fromSize + (to.size - fromSize) * t
                radius = (fromRadius + (to.radius - fromRadius) * t).coerceAtLeast(0f)
                color = evaluator.evaluate(it.animatedFraction, fromColor, to.color) as Int
                invalidate()
            }
            start()
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val px = (BUTTON_DP * density).toInt()
        setMeasuredDimension(px, px)
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        canvas.drawCircle(cx, cy, BUTTON_DP * density / 2, ringPaint)
        innerPaint.color = color
        val half = size / 2
        val r = radius.coerceAtMost(half)
        canvas.drawRoundRect(RectF(cx - half, cy - half, cx + half, cy + half), r, r, innerPaint)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!isEnabled) return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downY = event.rawY
                longPressFired = false
                parent?.requestDisallowInterceptTouchEvent(true)
                if (state == State.PHOTO || state == State.VIDEO) animateTo(target(state, pressed = true))
                if (state == State.PHOTO && holdToRecord) {
                    postDelayed(longPress, ViewConfiguration.getLongPressTimeout().toLong())
                }
            }
            MotionEvent.ACTION_MOVE ->
                if (longPressFired) onHoldDrag(event.rawY - downY)
            MotionEvent.ACTION_UP -> {
                removeCallbacks(longPress)
                if (longPressFired) {
                    onHoldEnd()
                } else {
                    if (state == State.PHOTO || state == State.VIDEO) animateTo(target(state))
                    performClick()
                }
                longPressFired = false
            }
            MotionEvent.ACTION_CANCEL -> {
                removeCallbacks(longPress)
                if (longPressFired) onHoldEnd() else animateTo(target(state))
                longPressFired = false
            }
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        onTap()
        return true
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(longPress)
        animator?.cancel()
        super.onDetachedFromWindow()
    }

    private companion object {
        const val BUTTON_DP = 76f
        const val IDLE_DP = 64f
        const val PRESSED_DP = 56f
        const val LOCKED_DP = 44f
        const val LOCKED_RADIUS_DP = 10f
        const val ANIM_MS = 220L
    }
}
