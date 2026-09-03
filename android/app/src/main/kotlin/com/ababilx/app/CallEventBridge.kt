package com.ababilx.app

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.ababilx.call_ringer.CallRinger
import com.ababilx.call_ringer.CallkitSurface
import com.hiennv.flutter_callkit_incoming.CallkitBackgroundExecutor
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import com.hiennv.flutter_callkit_incoming.getPluginCallbackHandle

/**
 * Last-resort handler for CallKit accept / decline / end, installed from
 * [AbabilXApplication] so it exists in **every** process, however that process
 * was started.
 *
 * Why it has to be native: `FlutterCallkitIncomingPlugin.send` delivers a call
 * event to the Flutter UI if an engine is listening, otherwise to the plugin's
 * background executor **only if that executor is already running** — and it is
 * started exclusively by `FlutterCallkitIncoming.onBackgroundMessage`, which
 * runs in `main()`. A process woken by an FCM push (killed app, incoming call)
 * never runs `main()`, so Decline pressed on the full-screen CallKit screen or
 * in the notification was dropped on the floor: the ringtone kept playing, the
 * call was never declined server-side, and opening the app found it still
 * ringing. Fixed 2026-08-26.
 *
 * `CallkitIncomingBroadcastReceiver` invokes this straight from the broadcast,
 * before it tries to deliver to Flutter, so:
 *  1. the ringtone stops immediately, with no Dart involved at all, and
 *  2. the plugin's background engine is started first, which makes the very
 *     next delivery attempt succeed and lets `androidCallkitBackgroundHandler`
 *     post the decline to the API.
 */
object CallEventBridge : CallkitEventCallback {

    private const val TAG = "CallEventBridge"

    /** Ring holder for CallKit's surface — mirrors `ring_holders.dart`. */
    private const val NATIVE_HOLDER = "native"

    private var appContext: Context? = null

    fun install(context: Context) {
        appContext = context.applicationContext
        // The plugin keeps a WeakReference; this object is a static singleton,
        // so the reference stays alive for the life of the process.
        FlutterCallkitIncomingPlugin.registerEventCallback(this)
    }

    override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
        val context = appContext ?: return
        // Answered, declined or ended — every one of them ends the ringing UI.
        CallRinger.release(NATIVE_HOLDER)
        // ...and the full-screen Activity a locked phone is showing, which the
        // plugin tries and fails to close on exactly these three events. See
        // [CallkitSurface]. Doing it here rather than from Dart covers a
        // killed app, and covers the ends we did not initiate.
        CallkitSurface.dismissIncoming(
            context,
            event == CallkitEventCallback.CallEvent.ACCEPT,
        )
        ensureBackgroundEngine(context)
    }

    /**
     * Boots the plugin's Dart background executor using the handle stored at
     * the app's last normal start, so the event about to be dispatched has
     * somewhere to land.
     */
    private fun ensureBackgroundEngine(context: Context) {
        if (CallkitBackgroundExecutor.registered) return
        val handle = getPluginCallbackHandle(context) ?: 0L
        if (handle == 0L) {
            Log.w(TAG, "no stored background handle — call event stays native-only")
            return
        }
        try {
            CallkitBackgroundExecutor.start(context, handle)
        } catch (error: Throwable) {
            Log.e(TAG, "background engine start failed", error)
        }
    }
}
