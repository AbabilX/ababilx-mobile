package com.ababilx.call_ringer

import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Closes flutter_callkit_incoming's full-screen incoming Activity.
 *
 * The plugin believes it already does this. `CallkitNotificationManager.
 * clearIncomingNotification` broadcasts `CallkitIncomingActivity.getIntentEnded`,
 * and the Activity registers a runtime receiver for that action in `onCreate`
 * which calls `finishTask()`. The intent never arrives, because the plugin
 * builds it with
 *
 *     intent.setClassName(pkg, "…flutter_callkit_incoming.CallkitIncomingActivity")
 *
 * and a broadcast carrying an explicit component is never matched against
 * runtime-registered receivers: `ActivityManagerService.broadcastIntentLocked`
 * only queries them `if (intent.getComponent() == null)`. The manifest lookup
 * that does run finds nothing either — the named component is an Activity, not
 * a `<receiver>`. So the broadcast is delivered to no one.
 *
 * What that costs on a real phone: the caller cancels, the notification is
 * cancelled and the ringtone released, and the callee's **locked** screen keeps
 * the incoming-call Activity until its own `duration` timer expires (up to a
 * minute). Answering that dead surface opens the app for a call that is over.
 * An unlocked phone never shows this — with no keyguard Android draws the
 * heads-up notification instead of firing the full-screen intent, and
 * cancelling the notification is the whole teardown.
 *
 * The same intent without the component matches. That is all this sends.
 * `setPackage` keeps it inside the app, which is what the Activity's
 * `RECEIVER_EXPORTED` registration needs to stay safe.
 *
 * It lives in this package for the reason the ringer does: a plugin package is
 * registered into every engine, so a killed app woken by an FCM push can still
 * take the surface down. See `packages/call_ringer/README` notes in
 * `lib/features/calls/CLAUDE.md`.
 */
object CallkitSurface {

    private const val TAG = "CallkitSurface"

    /** The action `CallkitIncomingActivity` listens on, prefixed by the app id. */
    private const val ACTION_ENDED_CALL_INCOMING =
        "com.hiennv.flutter_callkit_incoming.ACTION_ENDED_CALL_INCOMING"

    /**
     * [accepted] mirrors the plugin's own flag: an answered call lets the
     * Activity finish a second later so its accept animation completes, any
     * other ending closes it at once.
     */
    fun dismissIncoming(context: Context, accepted: Boolean) {
        val app = context.applicationContext
        val intent = Intent("${app.packageName}.$ACTION_ENDED_CALL_INCOMING").apply {
            putExtra("ACCEPTED", accepted)
            setPackage(app.packageName)
        }
        try {
            app.sendBroadcast(intent)
        } catch (error: Throwable) {
            // Nothing was showing, or the Activity is already gone.
            Log.w(TAG, "incoming activity dismiss failed", error)
        }
    }
}
