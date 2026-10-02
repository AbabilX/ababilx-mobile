package com.ababilx.app.mediasend.camera

import android.content.Context
import android.view.OrientationEventListener
import android.view.Surface

/**
 * Which way the phone is physically held, while the camera screen itself
 * stays portrait — Signal's arrangement on a phone: the layout never jumps,
 * photos still come out upright ([CameraSession.setTargetRotation]) and only
 * the icons turn ([iconDegrees]).
 *
 * A rotation is committed only once the phone is within 15° of a quadrant's
 * middle, so one held near 45° keeps what it had instead of flapping.
 */
class DeviceRotation(
    context: Context,
    private val onChanged: (surfaceRotation: Int, iconDegrees: Float) -> Unit,
) {

    var rotation = Surface.ROTATION_0
        private set

    private val listener = object : OrientationEventListener(context) {
        override fun onOrientationChanged(degrees: Int) {
            if (degrees == ORIENTATION_UNKNOWN) return
            val next = quadrant(degrees) ?: return
            if (next != rotation) {
                rotation = next
                onChanged(next, iconDegrees)
            }
        }
    }

    fun start() {
        if (listener.canDetectOrientation()) listener.enable()
    }

    fun stop() = listener.disable()

    /** What to turn an upright icon by so it reads level in the user's hand. */
    val iconDegrees: Float
        get() = when (rotation) {
            Surface.ROTATION_90 -> 90f
            Surface.ROTATION_180 -> 180f
            Surface.ROTATION_270 -> -90f
            else -> 0f
        }

    private fun quadrant(degrees: Int): Int? = when {
        degrees >= 360 - HOLD || degrees <= HOLD -> Surface.ROTATION_0
        degrees in (90 - HOLD)..(90 + HOLD) -> Surface.ROTATION_270
        degrees in (180 - HOLD)..(180 + HOLD) -> Surface.ROTATION_180
        degrees in (270 - HOLD)..(270 + HOLD) -> Surface.ROTATION_90
        else -> null
    }

    private companion object {
        /** Half of a quadrant minus the 30° dead band either side. */
        const val HOLD = 15
    }
}
