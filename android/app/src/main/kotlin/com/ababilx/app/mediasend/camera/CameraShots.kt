package com.ababilx.app.mediasend.camera

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.WindowManager
import com.ababilx.app.R
import java.io.File
import java.util.concurrent.Executor

/**
 * Taking the shot, with everything Signal does around it:
 *
 * - a 50 ms buzz as the shutter goes, and a dark blink over the card;
 * - **selfie flash**: front lens + flash "On" has no flash to fire, so the
 *   screen goes white at full brightness for 150 ms before the capture and
 *   comes back after it;
 * - one capture at a time — a second tap while the first is still writing is
 *   ignored rather than queued.
 */
class CameraShots(
    private val activity: Activity,
    private val session: CameraSession,
    io: Executor,
    private val shutter: View,
    private val selfieFlash: View,
    private val onPhoto: (File) -> Unit,
    private val onVideo: (File) -> Unit,
    private val onRecording: (recording: Boolean) -> Unit,
    onTick: (Long) -> Unit,
    private val onFailed: (messageRes: Int) -> Unit,
) {

    private val photos = CameraPhoto(activity, io)
    private val recorder = CameraRecorder(
        context = activity,
        session = session,
        onStarted = { buzz() },
        onTick = onTick,
        onFinished = { file, _ ->
            onRecording(false)
            if (file != null) onVideo(file) else onFailed(R.string.media_send_video_failed)
        },
    )
    private var capturing = false
    private var savedBrightness: Float? = null

    val isRecording: Boolean get() = recorder.isRecording

    fun photo() {
        if (capturing || recorder.isRecording) return
        val capture = session.imageCapture ?: return
        capturing = true
        if (session.isFront && session.flash == CameraFlash.ON) {
            lightFace(true)
            selfieFlash.postDelayed({ take(capture) }, SELFIE_FLASH_MS)
        } else {
            take(capture)
        }
    }

    /** @return false when the camera could not record at all. */
    fun startRecording(): Boolean {
        if (capturing || recorder.isRecording) return recorder.isRecording
        val started = recorder.start()
        if (started) onRecording(true) else onFailed(R.string.media_send_video_failed)
        return started
    }

    fun stopRecording() = recorder.stop()

    private fun take(capture: androidx.camera.core.ImageCapture) {
        buzz()
        blink()
        photos.take(capture, mirror = session.isFront) { file ->
            capturing = false
            lightFace(false)
            if (file != null) onPhoto(file) else onFailed(R.string.media_send_photo_failed)
        }
    }

    private fun blink() {
        shutter.animate().cancel()
        shutter.alpha = SHUTTER_ALPHA
        shutter.animate().alpha(0f).setStartDelay(0).setDuration(SHUTTER_MS).start()
    }

    private fun lightFace(on: Boolean) {
        val window = activity.window
        val params = window.attributes
        if (on) {
            savedBrightness = params.screenBrightness
            params.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
            selfieFlash.visibility = View.VISIBLE
        } else {
            val saved = savedBrightness ?: return
            params.screenBrightness = saved
            savedBrightness = null
            selfieFlash.visibility = View.GONE
        }
        window.attributes = params
    }

    @Suppress("DEPRECATION")
    private fun buzz() {
        val vibrator = activity.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            vibrator.vibrate(VibrationEffect.createOneShot(BUZZ_MS, BUZZ_AMPLITUDE))
        } else {
            vibrator.vibrate(BUZZ_MS)
        }
    }

    private companion object {
        const val SELFIE_FLASH_MS = 150L
        const val SHUTTER_ALPHA = 0.85f
        const val SHUTTER_MS = 220L
        const val BUZZ_MS = 50L
        const val BUZZ_AMPLITUDE = 75
    }
}
