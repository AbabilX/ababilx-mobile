package com.ababilx.app

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Watches the audio mode and the communication device while the ringback
 * plays — Signal's `FullSignalAudioManagerApi31` listeners, for the same
 * reason: the platform can take the mode or the route back on its own, and
 * Signal re-asserts the user's device when the communication device moves
 * away from it.
 *
 * Every change is logged under `CallRingback`, so a ring that goes quiet or
 * drops to the earpiece names the moment and the cause in logcat.
 */
@RequiresApi(Build.VERSION_CODES.S)
class CallRingbackWatch(
    private val audio: AudioManager,
    private val onDrift: (reason: String) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var watching = false

    /** What the ringback wants: the loudspeaker, or not. */
    var wantSpeaker = false

    private val modeListener = AudioManager.OnModeChangedListener { mode ->
        Log.i(TAG, "mode changed: ${modeName(mode)}")
        if (mode != AudioManager.MODE_IN_COMMUNICATION && mode != AudioManager.MODE_IN_CALL) {
            onDrift("mode ${modeName(mode)}")
        }
    }

    private val deviceListener = AudioManager.OnCommunicationDeviceChangedListener { device ->
        Log.i(TAG, "communication device: ${device?.type ?: "null"} wantSpeaker=$wantSpeaker")
        val onSpeaker = device?.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        if (wantSpeaker && !onSpeaker) onDrift("device ${device?.type ?: "null"}")
    }

    fun start() {
        if (watching) return
        watching = true
        runCatching {
            audio.addOnModeChangedListener(handler::post, modeListener)
            audio.addOnCommunicationDeviceChangedListener(handler::post, deviceListener)
        }.onFailure { Log.w(TAG, "watch start failed", it) }
    }

    fun stop() {
        if (!watching) return
        watching = false
        runCatching {
            audio.removeOnModeChangedListener(modeListener)
            audio.removeOnCommunicationDeviceChangedListener(deviceListener)
        }
    }

    private fun modeName(mode: Int): String = when (mode) {
        AudioManager.MODE_NORMAL -> "NORMAL"
        AudioManager.MODE_RINGTONE -> "RINGTONE"
        AudioManager.MODE_IN_CALL -> "IN_CALL"
        AudioManager.MODE_IN_COMMUNICATION -> "IN_COMMUNICATION"
        else -> "$mode"
    }

    private companion object {
        const val TAG = "CallRingback"
    }
}
