package com.ababilx.app.callaudio

import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.telecom.Connection
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitConnection

/**
 * The one owner of a call's audio: mode, focus, microphone mute and which
 * device the call plays through.
 *
 * Signal-Android's `SignalAudioManager`, ported — Signal is AGPL, so the code
 * is ours and the mechanism is theirs. Every command runs on its own thread
 * ("call-audio"), the device list is watched for the whole call, and a device
 * that appears mid-call (Bluetooth connects, a headset is plugged in) is
 * picked up there: Bluetooth first, then wired, then the call's default, then
 * earpiece, then speaker — unless the user chose something else.
 *
 * Three implementations, chosen as Signal chooses them:
 * - [TelecomCallAudioManager] when Android Telecom hosts the call (answered
 *   from the CallKit notification): Telecom owns mode and routing.
 * - [CallAudioManager31] on Android 12+: `setCommunicationDevice`.
 * - [CallAudioManagerLegacy] below it: speakerphone + Bluetooth SCO.
 */
abstract class CallAudioManager(
    protected val context: Context,
    protected val listener: Listener,
) {
    fun interface Listener {
        fun onAudioDeviceChanged(snapshot: CallAudioSnapshot)
    }

    enum class State { UNINITIALIZED, RUNNING }

    private val thread = HandlerThread("call-audio").apply { start() }
    protected val handler = Handler(thread.looper)
    protected val audio: AudioManager = context.getSystemService(AudioManager::class.java)

    protected var state = State.UNINITIALIZED
    protected var savedMode = AudioManager.MODE_INVALID
    protected var savedMicMute = false
    private var focus: AudioFocusRequest? = null

    /** The newest snapshot, for a screen that opens after the last change. */
    @Volatile
    var snapshot: CallAudioSnapshot? = null
        private set

    fun post(block: () -> Unit) {
        handler.post { runCatching(block).onFailure { Log.e(TAG, "command failed", it) } }
    }

    /** Stops the call's audio and ends the thread; the manager is spent. */
    fun shutdown() {
        handler.post {
            runCatching { stop() }.onFailure { Log.e(TAG, "stop failed", it) }
            thread.quitSafely()
        }
    }

    /** Initialize + start: watch devices, take focus, MODE_IN_COMMUNICATION. */
    abstract fun start()

    abstract fun stop()

    abstract fun setDefaultAudioDevice(device: CallAudioDevice, clearUserEarpieceSelection: Boolean)

    /** [id] is a [CallAudioOption.id] from this manager's own snapshot. */
    abstract fun selectAudioDevice(id: Int)

    /** The first option of [device]'s kind, as a picker press would choose it. */
    fun selectAudioDevice(device: CallAudioDevice) {
        val option = snapshot?.options?.firstOrNull { it.device == device } ?: return
        selectAudioDevice(option.id)
    }

    protected fun publish(next: CallAudioSnapshot) {
        snapshot = next
        listener.onAudioDeviceChanged(next)
    }

    protected fun setMode(mode: Int, caller: String) {
        runCatching { audio.mode = mode }
        Log.i(TAG, "$caller: requested ${modeName(mode)}")
    }

    protected fun setMicrophoneMute(on: Boolean) {
        if (audio.isMicrophoneMute != on) audio.isMicrophoneMute = on
    }

    protected fun hasEarpiece(): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)

    /** Signal's call focus: transient exclusive, voice communication. */
    @Suppress("DEPRECATION")
    protected fun requestCallAudioFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            audio.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, FOCUS)
            return
        }
        if (focus != null) return
        val request = AudioFocusRequest.Builder(FOCUS)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .build(),
            )
            .setOnAudioFocusChangeListener { Log.i(TAG, "focus changed: $it") }
            .build()
        val granted = audio.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        Log.i(TAG, "audio focus gained: $granted")
        focus = request
    }

    @Suppress("DEPRECATION")
    protected fun abandonCallAudioFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            audio.abandonAudioFocus(null)
            return
        }
        focus?.let { audio.abandonAudioFocusRequest(it) }
        focus = null
    }

    protected fun modeName(mode: Int): String = when (mode) {
        AudioManager.MODE_NORMAL -> "MODE_NORMAL"
        AudioManager.MODE_RINGTONE -> "MODE_RINGTONE"
        AudioManager.MODE_IN_CALL -> "MODE_IN_CALL"
        AudioManager.MODE_IN_COMMUNICATION -> "MODE_IN_COMMUNICATION"
        else -> "UNKNOWN($mode)"
    }

    companion object {
        const val TAG = "CallAudio"
        private const val FOCUS = AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE

        /** Signal's `SignalAudioManager.create`, with our Telecom host in place of Core Telecom. */
        fun create(context: Context, callId: String?, listener: Listener): CallAudioManager {
            val hosted = telecomConnection(callId)
            return when {
                hosted != null -> TelecomCallAudioManager(context, listener, hosted)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> CallAudioManager31(context, listener)
                else -> CallAudioManagerLegacy(context, listener)
            }
        }

        /** The plugin registers its Telecom calls from O; only an active one owns the audio. */
        private fun telecomConnection(callId: String?): CallkitConnection? {
            if (callId.isNullOrEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
            return CallkitConnection.find(callId)?.takeIf { it.state == Connection.STATE_ACTIVE }
        }
    }
}
