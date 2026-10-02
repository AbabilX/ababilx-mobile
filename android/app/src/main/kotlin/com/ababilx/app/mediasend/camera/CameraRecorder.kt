package com.ababilx.app.mediasend.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Recording
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import com.ababilx.app.mediasend.MediaSendExport
import java.io.File

/**
 * One video recording at a time, into the flow's cache folder.
 *
 * Signal's rules, kept:
 * - flash "On" on the back lens means the torch for the length of the take;
 * - the microphone is used when it is granted and silently skipped when it is
 *   not — a refused mic must not cost the user the video;
 * - a take that finalises with an error, or with no bytes, is not a video.
 *
 * [onTick] reports the elapsed time once a second for the timer pill;
 * [onFinished] gets the file, or null for a failed or empty take.
 */
class CameraRecorder(
    private val context: Context,
    private val session: CameraSession,
    private val onStarted: () -> Unit,
    private val onTick: (elapsedMs: Long) -> Unit,
    private val onFinished: (file: File?, durationMs: Long) -> Unit,
) {

    private val main = Handler(Looper.getMainLooper())
    private var recording: Recording? = null
    private var startedAt = 0L
    private var torch = false

    val isRecording: Boolean get() = recording != null

    private val ticker = object : Runnable {
        override fun run() {
            if (recording == null) return
            onTick(SystemClock.elapsedRealtime() - startedAt)
            main.postDelayed(this, TICK_MS)
        }
    }

    /** @return false when no recording could be started at all. */
    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        if (recording != null) return true
        val capture = session.ensureVideo() ?: return false
        val file = MediaSendExport.cacheFile(context, "video-${System.currentTimeMillis()}.mp4")
        torch = session.flash == CameraFlash.ON && !session.isFront
        if (torch) session.torch(true)

        val pending = capture.output.prepareRecording(context, FileOutputOptions.Builder(file).build())
        val withAudio = if (micGranted()) pending.withAudioEnabled() else pending
        recording = try {
            withAudio.start(ContextCompat.getMainExecutor(context)) { event -> onEvent(event, file) }
        } catch (error: Exception) {
            Log.w(TAG, "recording refused to start", error)
            if (torch) session.torch(false)
            session.restorePhoto()
            return false
        }
        return true
    }

    fun stop() {
        recording?.stop()
        recording = null
        main.removeCallbacks(ticker)
    }

    private fun onEvent(event: VideoRecordEvent, file: File) {
        when (event) {
            is VideoRecordEvent.Start -> {
                startedAt = SystemClock.elapsedRealtime()
                onStarted()
                main.post(ticker)
            }
            is VideoRecordEvent.Finalize -> {
                main.removeCallbacks(ticker)
                recording = null
                if (torch) session.torch(false)
                session.restorePhoto()
                val ok = !event.hasError() && file.length() > 0
                if (!ok) Log.w(TAG, "recording failed: ${event.error}", event.cause)
                val duration = event.recordingStats.recordedDurationNanos / 1_000_000
                onFinished(if (ok) file else null, duration)
            }
        }
    }

    private fun micGranted() = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

    private companion object {
        const val TAG = "CameraRecorder"
        const val TICK_MS = 250L
    }
}
