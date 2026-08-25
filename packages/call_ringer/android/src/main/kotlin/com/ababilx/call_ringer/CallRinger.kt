package com.ababilx.call_ringer

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * The single owner of the incoming-call ringtone on Android.
 *
 * flutter_callkit_incoming plays its own ringtone through
 * `CallkitSoundPlayerManager`, which kills the sound on `ACTION_SCREEN_OFF`
 * and on any `android.media.VOLUME_CHANGED_ACTION` broadcast — an OEM
 * increasing-ring-volume ramp or a screen blink silenced a ringing call a
 * couple of seconds in, permanently. The plugin is therefore handed a silent
 * raw file (`AndroidParams.ringtonePath = 'silent_ring'`) and keeps only the
 * notification and vibration, while this object plays the actual tone for
 * every path: CallKit ringing raised from the FCM background isolate and the
 * in-app `/call` screen.
 *
 * It lives in a Flutter plugin package rather than the app module because
 * `FlutterEngine(context)` registers plugins on every engine it builds — the
 * two background isolates (FCM pushes, CallKit events on a killed app)
 * included. An app-module method channel exists only while the Activity does,
 * and the plugin's own call broadcasts are explicit intents no other receiver
 * can observe.
 *
 * Like Signal's `IncomingRinger`, the tone stops for exactly three reasons:
 * the call was answered, the call ended, or the ring window expired. Screen
 * state, volume changes and audio focus are deliberately not consulted — a
 * `MediaPlayer` that requests no focus is never paused behind our back.
 */
object CallRinger {

    private const val TAG = "CallRinger"

    /** Ring windows are 60s server-side; this only catches a lost stop event. */
    private const val MAX_RING_MS = 70_000L

    private val holders = mutableSetOf<String>()
    private val main = Handler(Looper.getMainLooper())

    private var player: MediaPlayer? = null
    private var expiry: Runnable? = null

    /**
     * Ring on behalf of [holder] (`native`, `flutter`). Idempotent.
     *
     * [requireNotificationUi] belongs to the CallKit hold: that surface is a
     * notification, so with notifications switched off there is nothing to
     * answer or silence, and a tone the user cannot stop is worse than none.
     */
    @Synchronized
    fun hold(context: Context, holder: String, requireNotificationUi: Boolean) {
        if (requireNotificationUi && !notificationsEnabled(context)) {
            Log.i(TAG, "notifications disabled — not ringing for $holder")
            return
        }
        holders.add(holder)
        ensurePlaying(context.applicationContext)
    }

    /** Release [holder]; the tone continues while any other holder remains. */
    @Synchronized
    fun release(holder: String) {
        holders.remove(holder)
        if (holders.isEmpty()) stopPlayer()
    }

    @Synchronized
    fun releaseAll() {
        holders.clear()
        stopPlayer()
    }

    /** Hold [holder] and play from the top even if it was already ringing. */
    @Synchronized
    fun restart(context: Context, holder: String, requireNotificationUi: Boolean) {
        if (requireNotificationUi && !notificationsEnabled(context)) return
        holders.add(holder)
        stopPlayer()
        ensurePlaying(context.applicationContext)
    }

    private fun ensurePlaying(context: Context) {
        if (holders.isEmpty() || player != null) return
        if (!audioAllowed(context)) {
            // Silent / vibrate-only phone: the notification still vibrates.
            Log.i(TAG, "ringer muted by ringer mode")
            armExpiry()
            return
        }
        for (uri in ringtoneCandidates(context)) {
            if (start(context, uri)) break
        }
        armExpiry()
    }

    private fun start(context: Context, uri: Uri): Boolean {
        return try {
            val next = MediaPlayer()
            next.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setLegacyStreamType(AudioManager.STREAM_RING)
                    .build(),
            )
            next.setDataSource(context, uri)
            next.isLooping = true
            next.setOnErrorListener { _, what, extra ->
                Log.w(TAG, "ringtone error what=$what extra=$extra uri=$uri")
                // Tear down off this callback: the listener can fire while
                // prepare() still holds this object's monitor.
                main.post { releaseAll() }
                true
            }
            next.prepare()
            next.start()
            player = next
            true
        } catch (error: Exception) {
            Log.w(TAG, "ringtone start failed uri=$uri", error)
            false
        }
    }

    private fun stopPlayer() {
        cancelExpiry()
        val current = player ?: return
        player = null
        try {
            current.stop()
        } catch (_: Exception) {
            // Already stopped or never prepared.
        }
        try {
            current.release()
        } catch (_: Exception) {
        }
    }

    private fun armExpiry() {
        cancelExpiry()
        val task = Runnable {
            Log.i(TAG, "ring window expired — stopping")
            releaseAll()
        }
        expiry = task
        main.postDelayed(task, MAX_RING_MS)
    }

    private fun cancelExpiry() {
        expiry?.let(main::removeCallbacks)
        expiry = null
    }
}
