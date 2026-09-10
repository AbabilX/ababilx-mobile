package com.ababilx.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * A call answered on a locked phone runs OVER the keyguard, and the phone
 * stays locked.
 *
 * Signal's `WebRtcCallActivity` holds `setShowWhenLocked(isOngoingCall)` for
 * the whole call, which is safe there because that Activity holds nothing but
 * the call. Ours is the one FlutterActivity for the entire app, so the flag
 * follows the call SCREEN, and two covers keep everything else behind the lock:
 *
 * - [CallLockWindow.cover], an opaque native view over the FlutterView, from the moment an
 *   Accept (or a tap on the ongoing-call notification) arrives until Dart has
 *   painted the call — a cold engine draws a whole boot sequence first — and
 *   again from the moment the call screen goes until the phone is unlocked;
 * - `CallLockScreenGuard` in Dart, which masks any other route in the very
 *   frame it would paint, because Dart draws before a message can reach here.
 *
 * Both covers exist only while the app is over the keyguard. Behind it, the
 * keyguard already hides the app, and masking there would flash on unlock.
 * The PIN pad came from the plugin asking for the keyguard to be dismissed
 * on Accept; `patches/callkit-accept.gradle` removes that request.
 */
class CallLockScreen(private val activity: Activity) {
    private val keyguard =
        activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
    private val handler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private val lockWindow = CallLockWindow(activity)

    /** Dart: a live call's own screen is the top route. */
    private var callVisible = false

    /** Dart: this engine holds a call that is ringing, connecting or up. */
    private var callLive = false

    /** Answered, or returned to, on a locked phone; its screen is not up yet. */
    private var awaitedCallId: String? = null
    private var overLock = false

    private val expire = Runnable {
        awaitedCallId = null
        apply()
    }
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = refresh()
    }

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> result.success(state())
                    "setCallState" -> {
                        setCallState(
                            visible = call.argument<Boolean>("visible") == true,
                            live = call.argument<Boolean>("live") == true,
                        )
                        result.success(null)
                    }
                    "release" -> {
                        release(call.argument<String>("callId") ?: "")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT).apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.registerReceiver(receiver, filter)
        }
    }

    /**
     * CallKit's Accept, or a tap on the ongoing-call notification — the only
     * two things that ever lift the app over a lock screen. A return tap counts
     * only while this engine says a call is live: the entry can outlive it.
     */
    fun handleIntent(intent: Intent?) {
        if (intent == null || !keyguard.isKeyguardLocked || callVisible) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val accept = intent.action == ACCEPT
        val callId = when {
            accept -> intent.getBundleExtra(CALL_DATA)?.let { it.getString(CALL_ID) ?: "" }
            intent.action == OngoingCallService.ACTION_RETURN_TO_CALL && callLive ->
                intent.getStringExtra(OngoingCallService.EXTRA_CALL_ID) ?: ""
            else -> null
        } ?: return
        awaitedCallId = callId
        handler.removeCallbacks(expire)
        // A cold engine has to boot, sign in and fetch the call before it can
        // draw one; a warm engine is already holding it.
        handler.postDelayed(expire, if (accept) ACCEPT_WAIT_MS else RETURN_WAIT_MS)
        lockWindow.cover(true)
        apply()
    }

    /** Unlocking hands the phone back; resume and screen on/off re-read it. */
    fun refresh() {
        if (!keyguard.isKeyguardLocked) {
            awaitedCallId = null
            handler.removeCallbacks(expire)
            lockWindow.cover(false)
        }
        apply()
    }

    private fun setCallState(visible: Boolean, live: Boolean) {
        callLive = live
        val appeared = visible && !callVisible
        val left = !visible && callVisible
        callVisible = visible
        if (appeared) {
            awaitedCallId = null
            handler.removeCallbacks(expire)
            // Dart reports this after the call's frame; lift the cover once
            // that frame has reached the screen.
            val decor = activity.window.decorView
            decor.postOnAnimation { decor.postOnAnimation { if (callVisible) lockWindow.cover(false) } }
        }
        // Cover first, then drop the flag: the keyguard animates back in over
        // whatever the next route paints.
        if (left && overLock && keyguard.isKeyguardLocked) lockWindow.cover(true)
        apply()
    }

    /** Dart ended a native call; if an Accept was waiting on it, none is coming. */
    private fun release(callId: String) {
        if (callId != awaitedCallId) return
        awaitedCallId = null
        handler.removeCallbacks(expire)
        apply()
    }

    private fun apply() {
        val want = callVisible || awaitedCallId != null
        if (want != overLock) {
            overLock = want
            lockWindow.setOverLock(want)
        }
        channel?.invokeMethod("changed", state())
    }

    private fun state() = mapOf(
        "locked" to keyguard.isKeyguardLocked,
        "overLock" to overLock,
    )

    fun dispose() {
        handler.removeCallbacksAndMessages(null)
        try {
            activity.unregisterReceiver(receiver)
        } catch (ignored: IllegalArgumentException) {
            // attach never ran.
        }
        channel?.setMethodCallHandler(null)
        channel = null
        lockWindow.setOverLock(false)
        lockWindow.cover(false)
    }

    companion object {
        private const val CHANNEL = "com.ababilx.app/call_lock_screen"
        private const val ACCEPT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"
        private const val CALL_DATA = "EXTRA_CALLKIT_CALL_DATA"
        private const val CALL_ID = "EXTRA_CALLKIT_ID"
        private const val ACCEPT_WAIT_MS = 30_000L
        private const val RETURN_WAIT_MS = 5_000L
    }
}
