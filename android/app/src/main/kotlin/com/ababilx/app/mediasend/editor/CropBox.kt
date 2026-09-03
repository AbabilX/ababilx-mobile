package com.ababilx.app.mediasend.editor

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.abs

/**
 * The crop rectangle and the finger that drags it.
 *
 * Lives in *view* coordinates while the gesture is happening and is converted
 * back to normalised image coordinates only when the crop is committed —
 * dragging a corner must not re-derive the image transform on every move.
 */
class CropBox {

    val rect = RectF()
    private var grab = Grab.NONE
    private var lastX = 0f
    private var lastY = 0f

    private val shade = Paint().apply { color = Color.parseColor("#A6000000") }
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }
    private val corner = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 6f
    }

    private enum class Grab { NONE, MOVE, TL, TR, BL, BR }

    fun reset(bounds: RectF) = rect.set(bounds)

    fun draw(canvas: Canvas, bounds: RectF) {
        // Everything outside the box is dimmed, so the crop reads as a window
        // onto the photo rather than a rectangle drawn on top of it.
        canvas.drawRect(bounds.left, bounds.top, bounds.right, rect.top, shade)
        canvas.drawRect(bounds.left, rect.bottom, bounds.right, bounds.bottom, shade)
        canvas.drawRect(bounds.left, rect.top, rect.left, rect.bottom, shade)
        canvas.drawRect(rect.right, rect.top, bounds.right, rect.bottom, shade)

        canvas.drawRect(rect, line)
        val third = rect.width() / 3f
        val thirdY = rect.height() / 3f
        for (i in 1..2) {
            canvas.drawLine(rect.left + third * i, rect.top, rect.left + third * i, rect.bottom, line)
            canvas.drawLine(rect.left, rect.top + thirdY * i, rect.right, rect.top + thirdY * i, line)
        }
        val arm = 22f
        canvas.drawLine(rect.left, rect.top, rect.left + arm, rect.top, corner)
        canvas.drawLine(rect.left, rect.top, rect.left, rect.top + arm, corner)
        canvas.drawLine(rect.right, rect.top, rect.right - arm, rect.top, corner)
        canvas.drawLine(rect.right, rect.top, rect.right, rect.top + arm, corner)
        canvas.drawLine(rect.left, rect.bottom, rect.left + arm, rect.bottom, corner)
        canvas.drawLine(rect.left, rect.bottom, rect.left, rect.bottom - arm, corner)
        canvas.drawLine(rect.right, rect.bottom, rect.right - arm, rect.bottom, corner)
        canvas.drawLine(rect.right, rect.bottom, rect.right, rect.bottom - arm, corner)
    }

    fun down(x: Float, y: Float) {
        lastX = x
        lastY = y
        grab = when {
            near(x, y, rect.left, rect.top) -> Grab.TL
            near(x, y, rect.right, rect.top) -> Grab.TR
            near(x, y, rect.left, rect.bottom) -> Grab.BL
            near(x, y, rect.right, rect.bottom) -> Grab.BR
            rect.contains(x, y) -> Grab.MOVE
            else -> Grab.NONE
        }
    }

    fun move(x: Float, y: Float, bounds: RectF) {
        if (grab == Grab.NONE) return
        val dx = x - lastX
        val dy = y - lastY
        lastX = x
        lastY = y
        when (grab) {
            Grab.MOVE -> {
                val shiftX = dx.coerceIn(bounds.left - rect.left, bounds.right - rect.right)
                val shiftY = dy.coerceIn(bounds.top - rect.top, bounds.bottom - rect.bottom)
                rect.offset(shiftX, shiftY)
            }
            Grab.TL -> {
                rect.left = (rect.left + dx).coerceIn(bounds.left, rect.right - MIN)
                rect.top = (rect.top + dy).coerceIn(bounds.top, rect.bottom - MIN)
            }
            Grab.TR -> {
                rect.right = (rect.right + dx).coerceIn(rect.left + MIN, bounds.right)
                rect.top = (rect.top + dy).coerceIn(bounds.top, rect.bottom - MIN)
            }
            Grab.BL -> {
                rect.left = (rect.left + dx).coerceIn(bounds.left, rect.right - MIN)
                rect.bottom = (rect.bottom + dy).coerceIn(rect.top + MIN, bounds.bottom)
            }
            Grab.BR -> {
                rect.right = (rect.right + dx).coerceIn(rect.left + MIN, bounds.right)
                rect.bottom = (rect.bottom + dy).coerceIn(rect.top + MIN, bounds.bottom)
            }
            Grab.NONE -> Unit
        }
    }

    fun up() {
        grab = Grab.NONE
    }

    private fun near(x: Float, y: Float, px: Float, py: Float) =
        abs(x - px) < TOUCH && abs(y - py) < TOUCH

    private companion object {
        const val TOUCH = 48f
        const val MIN = 80f
    }
}
