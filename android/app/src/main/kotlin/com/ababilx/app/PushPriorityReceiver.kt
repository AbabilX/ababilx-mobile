package com.ababilx.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Logs, per push, the priority FCM delivered it at against the priority the
 * server asked for.
 *
 * FCM lowers an install's high-priority messages to normal once it has seen
 * them arrive without a visible notification, and a demoted phone then gets
 * its calls and DMs only when Doze lets it — which is exactly "the phone went
 * to sleep and stopped ringing". Nothing in Dart can see it: `RemoteMessage`
 * in the Flutter plugin carries no priority. This receiver sits beside the
 * plugin's own on the same FCM broadcast (a manifest broadcast reaches every
 * matching receiver in the package), reads the two keys and writes one
 * logcat line; it never touches the result, so the plugin's handling is
 * unchanged.
 *
 *   adb logcat -s AbabilXPush
 *
 * The keys are firebase-messaging's `Constants.MessagePayloadKeys`, read raw
 * because the plugin keeps that SDK off this module's classpath.
 */
class PushPriorityReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras ?: return
        val type = extras.getString("type").orEmpty()
        val original = extras.getString(KEY_ORIGINAL) ?: extras.getString(KEY_PRIORITY)
        val delivered = extras.getString(KEY_DELIVERED)
            ?: if (extras.getString(KEY_REDUCED) == "1") "normal" else extras.getString(KEY_PRIORITY)
        val lowered = original == "high" && delivered != "high"
        val line = "push type=$type original=$original delivered=$delivered"
        if (lowered) Log.w(TAG, "$line LOWERED") else Log.i(TAG, line)
    }

    private companion object {
        const val TAG = "AbabilXPush"
        const val KEY_PRIORITY = "google.priority"
        const val KEY_REDUCED = "google.priority_reduced"
        const val KEY_DELIVERED = "google.delivered_priority"
        const val KEY_ORIGINAL = "google.original_priority"
    }
}
