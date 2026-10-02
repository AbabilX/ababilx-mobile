package com.ababilx.app.mediasend.camera

import android.annotation.SuppressLint
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View

/**
 * What a finger does on the viewfinder — Signal's three gestures:
 * tap to focus there (with a ring that fades), double tap to switch lens,
 * pinch to zoom.
 *
 * A pinch must not also read as a tap, so a gesture that scaled is not
 * offered to the tap detector's single-tap-confirmed callback.
 */
class ViewfinderGestures(
    private val surface: View,
    private val focusRing: View,
    private val session: () -> CameraSession?,
    private val onDoubleTap: () -> Unit,
) {

    private var scaled = false

    private val taps = GestureDetector(
        surface.context,
        object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent) = true

            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                if (scaled) return false
                session()?.focus(e.x, e.y)
                showRing(e.x, e.y)
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                onDoubleTap()
                return true
            }
        },
    )

    private val pinch = ScaleGestureDetector(
        surface.context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                scaled = true
                session()?.pinch(detector.scaleFactor)
                return true
            }
        },
    )

    @SuppressLint("ClickableViewAccessibility")
    fun install() {
        surface.setOnTouchListener { _, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN) scaled = false
            pinch.onTouchEvent(event)
            taps.onTouchEvent(event)
            true
        }
    }

    private fun showRing(x: Float, y: Float) {
        focusRing.animate().cancel()
        focusRing.translationX = x - focusRing.width / 2f
        focusRing.translationY = y - focusRing.height / 2f
        focusRing.alpha = 1f
        focusRing.scaleX = 1.3f
        focusRing.scaleY = 1.3f
        focusRing.animate()
            .scaleX(1f)
            .scaleY(1f)
            // The fade below leaves its delay on the shared animator.
            .setStartDelay(0)
            .setDuration(RING_IN_MS)
            .withEndAction {
                focusRing.animate().alpha(0f).setStartDelay(RING_HOLD_MS).setDuration(RING_OUT_MS).start()
            }
            .start()
    }

    private companion object {
        const val RING_IN_MS = 180L
        const val RING_HOLD_MS = 600L
        const val RING_OUT_MS = 250L
    }
}
