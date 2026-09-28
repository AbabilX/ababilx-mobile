package com.ababilx.app

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The caller's "tuut… tuut…" while the other phone rings.
 *
 * Signal's `OutgoingRinger` plays a looping file on the voice-communication
 * usage after switching to `MODE_IN_COMMUNICATION`; that mode is what puts it
 * on the earpiece. We keep the model and use the platform's own ringback
 * ([ToneGenerator.TONE_SUP_RINGTONE]) instead of an asset: it already loops
 * with the local cadence, and Signal's sound file is AGPL.
 *
 * The audio mode is only changed if nobody else had set a call mode yet, and
 * is handed back on stop. It must be back to its old value before the call
 * connects: LiveKit saves the mode it finds when it activates and restores it
 * after the call, so leaving ours there would strand the phone in
 * communication mode once the call is over.
 *
 * Activity-scoped, like [CallScreenLock]: an outgoing call lives in the
 * Flutter isolate, so no engine means nothing to ring for.
 */
class CallRingback(private val activity: Activity) {

    private val audio by lazy {
        activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private var channel: MethodChannel? = null
    private var tone: ToneGenerator? = null
    private var focus: AudioFocusRequest? = null

    /** The mode found at start, when this class changed it; else null. */
    private var savedMode: Int? = null
    private var speakerForced = false

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        start(call.argument<Boolean>("speaker") ?: false)
                        result.success(null)
                    }
                    "stop" -> {
                        stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        stop()
    }

    /** Idempotent: a second start only re-applies the speaker choice. */
    private fun start(speaker: Boolean) {
        if (tone == null) {
            val mode = audio.mode
            if (mode != AudioManager.MODE_IN_COMMUNICATION && mode != AudioManager.MODE_IN_CALL) {
                runCatching { audio.mode = AudioManager.MODE_IN_COMMUNICATION }
                    .onSuccess { savedMode = mode }
            }
            requestFocus()
        }
        route(speaker)
        if (tone != null) return
        tone = runCatching {
            ToneGenerator(AudioManager.STREAM_VOICE_CALL, VOLUME).also {
                it.startTone(ToneGenerator.TONE_SUP_RINGTONE)
            }
        }.onFailure { Log.w(TAG, "ringback start failed", it) }.getOrNull()
    }

    private fun stop() {
        tone?.let { held ->
            runCatching { held.stopTone() }
            runCatching { held.release() }
        }
        tone = null
        route(false)
        abandonFocus()
        savedMode?.let { mode ->
            if (audio.mode == AudioManager.MODE_IN_COMMUNICATION) {
                runCatching { audio.mode = mode }
            }
        }
        savedMode = null
    }

    /** Only undoes a loudspeaker this class forced, never somebody else's. */
    @Suppress("DEPRECATION")
    private fun route(speaker: Boolean) {
        if (speaker == speakerForced) return
        speakerForced = speaker
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!speaker) {
                runCatching { audio.clearCommunicationDevice() }
                return
            }
            val device = audio.availableCommunicationDevices
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER } ?: return
            runCatching { audio.setCommunicationDevice(device) }
            return
        }
        runCatching { audio.isSpeakerphoneOn = speaker }
    }

    private fun requestFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || focus != null) return
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
        runCatching { audio.requestAudioFocus(request) }.onSuccess { focus = request }
    }

    private fun abandonFocus() {
        val held = focus ?: return
        focus = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            runCatching { audio.abandonAudioFocusRequest(held) }
        }
    }

    companion object {
        private const val CHANNEL = "com.ababilx.app/call_ringback"
        private const val TAG = "CallRingback"

        /** Percent of the voice-call stream; the tone is a cue, not a ring. */
        private const val VOLUME = 70
    }
}
