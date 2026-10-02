package com.ababilx.app

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The caller's "tuut… tuut…" while the other phone rings.
 *
 * Signal's `OutgoingRinger`, exactly: `MODE_IN_COMMUNICATION`, then a looping
 * [MediaPlayer] on `USAGE_VOICE_COMMUNICATION` / `CONTENT_TYPE_SPEECH`. The
 * file is our own (`res/raw/call_ringback.wav`, 440+480 Hz, 2 s on / 4 s off);
 * Signal's is AGPL.
 *
 * It has to be a MediaPlayer. This used `ToneGenerator`, which AudioService
 * does not count as a player: from Android 12 it re-checks an app that set
 * `MODE_IN_COMMUNICATION` after 6 s (`CHECK_MODE_FOR_UID_PERIOD_MS`) and, with
 * no active playback or recording from that uid, drops the mode to NORMAL —
 * which clears the communication device. The Speaker choice lasted two beeps
 * and the rest came out of the earpiece. A MediaPlayer is a tracked player, so
 * the mode, and the loudspeaker with it, holds for the whole ring.
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
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null

    /** The mode found at start, when this class changed it; else null. */
    private var savedMode: Int? = null
    private var speakerForced = false
    private var wantSpeaker = false

    /** Re-asserts left this ring; a platform that keeps undoing us wins. */
    private var repairs = 0

    private val watch: CallRingbackWatch? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            CallRingbackWatch(audio) { reason -> repair(reason) }
        } else {
            null
        }
    }

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
        wantSpeaker = speaker
        watch?.wantSpeaker = speaker
        if (player == null) {
            Log.i(TAG, "start speaker=$speaker mode=${audio.mode}")
            repairs = MAX_REPAIRS
            enterCommunication()
            requestFocus()
            watch?.start()
        }
        route(speaker)
        if (player == null) player = newPlayer()
    }

    private fun enterCommunication() {
        val mode = audio.mode
        if (mode == AudioManager.MODE_IN_COMMUNICATION || mode == AudioManager.MODE_IN_CALL) return
        runCatching { audio.mode = AudioManager.MODE_IN_COMMUNICATION }
            .onSuccess { if (savedMode == null) savedMode = mode }
    }

    /**
     * The platform took the mode or the route back mid-ring. Signal re-asserts
     * the user's device when the communication device moves off it; so do we,
     * a bounded number of times so the two of us never fight forever.
     */
    private fun repair(reason: String) {
        if (player == null) return
        if (repairs <= 0) {
            Log.w(TAG, "drift ($reason), no repairs left")
            return
        }
        repairs--
        Log.w(TAG, "drift ($reason), re-asserting speaker=$wantSpeaker")
        enterCommunication()
        route(wantSpeaker, force = true)
    }

    private fun newPlayer(): MediaPlayer? = CallRingbackPlayer.create(activity) { failed ->
        if (player === failed) player = newPlayer()
    }

    private fun stop() {
        if (player != null) Log.i(TAG, "stop")
        watch?.stop()
        player?.let { held -> runCatching { held.release() } }
        player = null
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
    private fun route(speaker: Boolean, force: Boolean = false) {
        if (speaker == speakerForced && !force) return
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
        private const val MAX_REPAIRS = 5
    }
}
