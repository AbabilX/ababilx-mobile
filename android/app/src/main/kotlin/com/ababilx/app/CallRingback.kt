package com.ababilx.app

import android.app.Activity
import android.media.MediaPlayer
import android.util.Log
import com.ababilx.app.callaudio.CallAudioSession
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The caller's "tuut… tuut…" while the other phone rings, and the short
 * "pip-pip" both sides hear while an answered call exchanges keys and opens
 * its media (Telegram's connecting sound; `res/raw/call_connecting.wav`, ours).
 *
 * Signal's `OutgoingRinger`, exactly: a looping [MediaPlayer] on
 * `USAGE_VOICE_COMMUNICATION` / `CONTENT_TYPE_SPEECH` ([CallRingbackPlayer]),
 * played inside the call's audio session. The file is our own
 * (`res/raw/call_ringback.wav`, 440+480 Hz, 2 s on / 4 s off); Signal's is AGPL.
 *
 * Mode, focus and the device it plays on are not this class's business any
 * more: they belong to the call's one audio owner, [CallAudioSession], as in
 * Signal, where `SignalAudioManager` starts the outgoing ringer itself. So the
 * ring follows whatever the call is on — the speaker the user chose, or a
 * Bluetooth / wired headset that connects while it rings — and the session
 * puts the route back if the platform moves it. If Dart's engine has not
 * started the session yet, the ringback starts it.
 *
 * It has to be a MediaPlayer. A `ToneGenerator` is not a tracked player:
 * from Android 12, AudioService drops `MODE_IN_COMMUNICATION` after 6 s
 * (`CHECK_MODE_FOR_UID_PERIOD_MS`) for an app with no active playback or
 * recording, and the call fell to the earpiece after two beeps.
 *
 * Activity-scoped, like [CallScreenLock]: an outgoing call lives in the
 * Flutter isolate, so no engine means nothing to ring for.
 */
class CallRingback(private val activity: Activity) {

    private var channel: MethodChannel? = null
    private var player: MediaPlayer? = null
    private var tone: String? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        start(
                            call.argument<String>("tone") ?: CallRingbackPlayer.TONE_RINGBACK,
                            call.argument<Boolean>("speaker") ?: false,
                        )
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

    /**
     * Idempotent per tone; a different tone replaces the one playing.
     * [speaker] only matters when this is what starts the session.
     *
     * The connecting tone never starts the session. On the answering phone
     * that would create it before the call's id is known to it, and the id is
     * what decides whether Telecom owns the route (`CallAudioManager.create`)
     * — a session started blind there loses the Speaker button for the call.
     * Dart's engine starts it a moment later and the tone follows its route.
     */
    private fun start(wanted: String, speaker: Boolean) {
        if (wanted == CallRingbackPlayer.TONE_RINGBACK) {
            CallAudioSession.ensureStarted(activity, speaker)
        }
        if (player != null && tone == wanted) return
        player?.let { old -> runCatching { old.release() } }
        Log.i(TAG, "start $wanted")
        tone = wanted
        player = newPlayer(wanted)
    }

    private fun newPlayer(wanted: String): MediaPlayer? =
        CallRingbackPlayer.create(activity, CallRingbackPlayer.resource(wanted)) { failed ->
            if (player === failed) player = newPlayer(wanted)
        }

    /** The ring only; the session stays for the call it belongs to. */
    private fun stop() {
        tone = null
        val held = player ?: return
        Log.i(TAG, "stop")
        player = null
        runCatching { held.release() }
    }

    companion object {
        private const val CHANNEL = "com.ababilx.app/call_ringback"
        private const val TAG = "CallRingback"
    }
}
