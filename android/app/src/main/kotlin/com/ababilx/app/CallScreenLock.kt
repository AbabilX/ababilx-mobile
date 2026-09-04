package com.ababilx.app

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * What a live call does to the display.
 *
 * Two jobs, both Signal's `LockManager`:
 *
 * - **Blank the screen at the ear.** A call held to the face used to leave the
 *   display lit against a cheek — burning battery and pressing Mute, Speaker
 *   and Hang up with it. `PROXIMITY_SCREEN_OFF_WAKE_LOCK` is the system's own
 *   answer: the sensor, not the app, decides when the panel is off, so this
 *   never has to poll or guess.
 * - **Stop the screen sleeping while a call screen is up.** Without it the
 *   display times out mid-call and the user has to unlock the phone to hang
 *   up.
 *
 * The proximity lock is held only while the call is on the **earpiece**. On
 * speaker, or through a headset, the phone is not at the face and blanking the
 * screen would be wrong — so the audio route is watched
 * ([AudioDeviceCallback]) and plugging in a headset mid-call drops the lock.
 *
 * Releasing uses [PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY] so a call
 * that ends while the phone is still at the ear does not flash the screen on
 * inside a pocket; it lights up when the phone comes away, the way every
 * dialler behaves.
 *
 * Activity-scoped, like [OngoingCallChannel] and for the same reason: a
 * connected call lives in the Flutter isolate, so no engine means no call.
 */
class CallScreenLock(private val activity: Activity) {

    private val power by lazy {
        activity.getSystemService(Context.POWER_SERVICE) as PowerManager
    }
    private val audio by lazy {
        activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private var channel: MethodChannel? = null
    private var lock: PowerManager.WakeLock? = null
    private var deviceCallback: AudioDeviceCallback? = null

    /** Dart says a call is connected and routed to the earpiece. */
    private var wanted = false

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(supported())
                    "setEarpieceCall" -> {
                        setWanted(call.argument<Boolean>("active") ?: false)
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        setKeepScreenOn(call.argument<Boolean>("on") ?: false)
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
        setWanted(false)
        setKeepScreenOn(false)
    }

    private fun setWanted(next: Boolean) {
        if (wanted == next) return
        wanted = next
        watchAudioDevices(next)
        apply()
    }

    private fun setKeepScreenOn(on: Boolean) {
        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (on) activity.window.addFlags(flag) else activity.window.clearFlags(flag)
    }

    /**
     * The lock is held only when a call wants it *and* the sound is coming out
     * of the earpiece. Called again on every audio-device change, so a headset
     * plugged in mid-call gives the screen back.
     */
    private fun apply() {
        if (wanted && !headsetConnected()) acquire() else release()
    }

    // A call has no bounded length, so a timeout would either cut the lock
    // short or be a lie; it is released explicitly instead.
    @SuppressLint("WakelockTimeout")
    private fun acquire() {
        if (!supported()) return
        val held = lock ?: runCatching {
            power.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, TAG).also { created ->
                created.setReferenceCounted(false)
                lock = created
            }
        }.getOrNull() ?: return
        if (held.isHeld) return
        runCatching { held.acquire() }
            .onFailure { Log.w(TAG, "proximity acquire failed", it) }
    }

    private fun release() {
        val held = lock ?: return
        if (!held.isHeld) return
        runCatching { held.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY) }
            .onFailure { Log.w(TAG, "proximity release failed", it) }
    }

    private fun supported(): Boolean = runCatching {
        power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)
    }.getOrDefault(false)

    @Suppress("DEPRECATION")
    private fun headsetConnected(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return audio.isWiredHeadsetOn
        return runCatching {
            audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in HEADSET_TYPES }
        }.getOrDefault(false)
    }

    private fun watchAudioDevices(on: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (on) {
            if (deviceCallback != null) return
            val callback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>?) = apply()
                override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>?) = apply()
            }
            deviceCallback = callback
            runCatching { audio.registerAudioDeviceCallback(callback, null) }
            return
        }
        val callback = deviceCallback ?: return
        deviceCallback = null
        runCatching { audio.unregisterAudioDeviceCallback(callback) }
    }

    companion object {
        private const val CHANNEL = "com.ababilx.app/call_screen_lock"
        private const val TAG = "ababilx:call-proximity"

        /**
         * Anything that means the sound is not leaving the earpiece. These are
         * compile-time constants, so the newer ones inline to plain ints and
         * never load a class the running OS does not have.
         */
        @SuppressLint("InlinedApi")
        private val HEADSET_TYPES = setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_HEARING_AID,
        )
    }
}
