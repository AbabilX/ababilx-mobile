package com.ababilx.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.Person

/**
 * The tray entry for a call in progress — ringing out, or connected.
 *
 * Shaped after Signal's `CallNotificationBuilder.TYPE_ESTABLISHED`: an ongoing
 * `CallStyle.forOngoingCall` notification whose body taps back into the call
 * screen and which carries a Hang up action, so a user who leaves the call
 * screen still has both a way back and a way out. Before this existed, backing
 * out of `/call` left the call running with no surface at all — the only way
 * to end it was for the other side to hang up or for the server sweeper to
 * expire it.
 *
 * It deliberately lives on its own low-importance channel: an ongoing call is
 * a status, not an alert, and it must never make a sound. Ringing is a
 * different surface entirely and belongs to CallKit + `call_ringer`.
 */
object OngoingCallNotification {

    /**
     * DEFAULT importance, silenced below — not Signal's LOW `call_status`.
     *
     * A locked Pixel hides LOW ("silent") entries from the lock screen, so a
     * call answered there and then minimised went on with no way back and no
     * Hang up short of the PIN. Signal never gets there: Back and Home enter
     * PiP, which Android gates on the PIN. A DM call here has no PiP, so the
     * entry has to be on the lock screen instead, the way a dialler's is — and
     * its tap goes through [CallReturnActivity], which needs no PIN either.
     * A channel's importance cannot be raised once created, hence a new id.
     */
    const val CHANNEL_ID = "call_ongoing"
    private const val LEGACY_CHANNEL_ID = "call_status"
    const val NOTIFICATION_ID = 9411

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return
        manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Ongoing calls",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Shown while you are on a call"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    fun build(
        context: Context,
        callId: String,
        title: String,
        subtitle: String,
        connected: Boolean,
        connectedAt: Long = 0L,
    ): android.app.Notification {
        ensureChannel(context)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIcon(context))
            .setContentTitle(title)
            .setContentText(subtitle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(connected)
            // A call that has not been answered yet has nothing to count, and
            // a timer beside "Calling…" reads as a call already in progress.
            .setUsesChronometer(connected)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(returnToCallIntent(context, callId))
        // The chronometer counts from `when`, which defaults to the moment the
        // notification is BUILT. Every re-post (each return to the app, each
        // phase change) rebuilt it, so the timer restarted from 00:00 and the
        // status-bar call chip never showed the real duration.
        if (connected && connectedAt > 0L) builder.setWhen(connectedAt)

        val hangUp = hangUpIntent(context, callId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // CallStyle is what makes Android render this as a call rather
            // than a generic ongoing notification — and on 14+ it is what puts
            // the entry at the top of the shade where a user looks for it.
            val person = Person.Builder().setName(title).build()
            builder.setStyle(NotificationCompat.CallStyle.forOngoingCall(person, hangUp))
        } else {
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Hang up",
                hangUp,
            )
        }
        return builder.build()
    }

    /**
     * Taps the body: bring the existing Flutter Activity back to the call —
     * through [CallReturnActivity], so a tap on the lock screen reaches the
     * call without the PIN pad.
     */
    private fun returnToCallIntent(context: Context, callId: String): PendingIntent {
        val intent = Intent(context, CallReturnActivity::class.java).apply {
            action = OngoingCallService.ACTION_RETURN_TO_CALL
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(OngoingCallService.EXTRA_CALL_ID, callId)
        }
        return PendingIntent.getActivity(
            context,
            REQUEST_RETURN,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun hangUpIntent(context: Context, callId: String): PendingIntent {
        val intent = Intent(context, OngoingCallService::class.java).apply {
            action = OngoingCallService.ACTION_HANG_UP
            putExtra(OngoingCallService.EXTRA_CALL_ID, callId)
        }
        return PendingIntent.getService(
            context,
            REQUEST_HANG_UP,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * The white status-bar icon the FCM notifications already use. Resolved by
     * name so this file does not depend on the generated `R` of the app module
     * being visible from here at edit time.
     */
    private fun smallIcon(context: Context): Int {
        val id = context.resources.getIdentifier(
            "ic_stat_ababilx",
            "drawable",
            context.packageName,
        )
        return if (id != 0) id else android.R.drawable.stat_sys_phone_call
    }

    private const val REQUEST_RETURN = 1
    private const val REQUEST_HANG_UP = 2
}
