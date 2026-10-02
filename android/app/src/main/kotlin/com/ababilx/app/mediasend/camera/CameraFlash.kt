package com.ababilx.app.mediasend.camera

import androidx.camera.core.ImageCapture
import com.ababilx.app.R

/**
 * The flash button's three settings, cycled Off → On → Auto → Off — Signal's
 * order, so the setting most people never want (always on) is one tap away
 * from off rather than two.
 *
 * On the front camera there is no flash to fire; "On" there means the screen
 * lights the face instead (see [CameraView.selfieFlash]), and Auto does
 * nothing, which is also what Signal does.
 */
enum class CameraFlash(val cameraxMode: Int, val icon: Int, val label: Int) {
    OFF(ImageCapture.FLASH_MODE_OFF, R.drawable.ic_ms_flash_off, R.string.media_send_flash_off),
    ON(ImageCapture.FLASH_MODE_ON, R.drawable.ic_ms_flash, R.string.media_send_flash_on),
    AUTO(ImageCapture.FLASH_MODE_AUTO, R.drawable.ic_ms_flash_auto, R.string.media_send_flash_auto);

    fun next(): CameraFlash = when (this) {
        OFF -> ON
        ON -> AUTO
        AUTO -> OFF
    }
}

/** What the capture button offers while it is waiting to be pressed. */
enum class CaptureMode { PHOTO, VIDEO }
