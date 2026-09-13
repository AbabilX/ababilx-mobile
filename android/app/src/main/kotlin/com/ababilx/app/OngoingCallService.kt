package com.ababilx.app

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * One foreground service for the whole connected call — Signal's
 * `ActiveCallForegroundService` shape.
 *
 * Two jobs, and they belong together on purpose:
 *
 *  1. It posts the ongoing-call notification, so leaving the call screen no
 *     longer strands the call (see [OngoingCallNotification]).
 *  2. It carries `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION` for the duration
 *     of a screen share, OR'd into the type mask exactly the way Signal's
 *     `serviceType()` does it.
 *
 * (2) replaces a second, separate foreground service: screen sharing used to
 * piggyback on flutter_local_notifications' generic `ForegroundService`, which
 * the manifest had to pin to `foregroundServiceType="mediaProjection"` app-wide.
 * That left two independent services running during a shared call, with the
 * MediaProjection's lifetime owned by flutter_webrtc and the service's lifetime
 * owned by a notification plugin — nothing sequenced the two, and tearing the
 * call down while sharing raced them. Android 14+ is strict about that pairing.
 * Keeping the projection type on the service that already owns the call means
 * one lifetime, torn down in one place.
 *
 * The service tracks the call only while this process is alive: the WebRTC
 * session lives in the Dart isolate, so a dead process is a dead call and
 * `stopWithTask` is correct.
 */
class OngoingCallService : Service() {

    private var callId: String = ""
    private var title: String = ""
    private var subtitle: String = ""
    private var screenSharing: Boolean = false
    private var connected: Boolean = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE -> {
                val requestId = intent.getLongExtra(EXTRA_REQUEST_ID, 0L)
                callId = intent.getStringExtra(EXTRA_CALL_ID) ?: callId
                title = intent.getStringExtra(EXTRA_TITLE) ?: title
                subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: subtitle
                screenSharing = intent.getBooleanExtra(EXTRA_SCREEN_SHARING, screenSharing)
                connected = intent.getBooleanExtra(EXTRA_CONNECTED, connected)
                if (!enterForeground()) {
                    OngoingCallBridge.completeForeground(requestId, false)
                    stopSelf()
                    return START_NOT_STICKY
                }
                OngoingCallBridge.completeForeground(requestId, true)
            }

            ACTION_HANG_UP -> {
                val id = intent.getStringExtra(EXTRA_CALL_ID) ?: callId
                Log.i(TAG, "hang up from notification call=$id")
                // Dart owns ending the call — this only reports the press. The
                // service stays up until Dart calls stop(), so the entry does
                // not blink out before the call is actually torn down.
                OngoingCallBridge.notifyHangUp(id)
            }

            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    /**
     * A receive-only call remains a real self-managed Telecom call, so it uses
     * phoneCall even when RECORD_AUDIO is unavailable. Microphone is added only
     * when granted; the service never claims capture it cannot perform.
     */
    private fun enterForeground(): Boolean {
        val notification =
            OngoingCallNotification.build(this, callId, title, subtitle, connected)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val type = serviceType()
                startForeground(OngoingCallNotification.NOTIFICATION_ID, notification, type)
            } else {
                startForeground(OngoingCallNotification.NOTIFICATION_ID, notification)
            }
            true
        } catch (error: Exception) {
            // A denied permission or a background-start restriction must never
            // take the call down with it; the call simply runs without a tray
            // entry, exactly as it did before this service existed.
            Log.w(TAG, "startForeground failed", error)
            false
        }
    }

    /**
     * The type mask, rebuilt on every start/update so the projection type is
     * added when sharing begins and dropped when it ends.
     */
    private fun serviceType(): Int = serviceTypeFor(
        hasMicrophone = hasPermission(Manifest.permission.RECORD_AUDIO),
        screenSharing = screenSharing,
    )

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "OngoingCallService"

        const val ACTION_START = "com.ababilx.app.ONGOING_CALL_START"
        const val ACTION_UPDATE = "com.ababilx.app.ONGOING_CALL_UPDATE"
        const val ACTION_STOP = "com.ababilx.app.ONGOING_CALL_STOP"
        const val ACTION_HANG_UP = "com.ababilx.app.ONGOING_CALL_HANG_UP"
        const val ACTION_RETURN_TO_CALL = "com.ababilx.app.ONGOING_CALL_RETURN"

        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_SCREEN_SHARING = "screen_sharing"
        const val EXTRA_CONNECTED = "connected"
        const val EXTRA_REQUEST_ID = "request_id"

        internal fun serviceTypeFor(hasMicrophone: Boolean, screenSharing: Boolean): Int {
            var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            if (hasMicrophone) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (screenSharing) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            return type
        }

        fun start(
            context: Context,
            requestId: Long,
            callId: String,
            title: String,
            subtitle: String,
            screenSharing: Boolean,
            connected: Boolean,
        ) = send(
            context, ACTION_START, requestId, callId, title, subtitle, screenSharing, connected,
        )

        fun update(
            context: Context,
            requestId: Long,
            callId: String,
            title: String,
            subtitle: String,
            screenSharing: Boolean,
            connected: Boolean,
        ) = send(
            context, ACTION_UPDATE, requestId, callId, title, subtitle, screenSharing, connected,
        )

        fun stop(context: Context) {
            val intent = Intent(context, OngoingCallService::class.java)
                .setAction(ACTION_STOP)
            try {
                context.startService(intent)
            } catch (error: Exception) {
                Log.w(TAG, "stop failed", error)
            }
        }

        private fun send(
            context: Context,
            action: String,
            requestId: Long,
            callId: String,
            title: String,
            subtitle: String,
            screenSharing: Boolean,
            connected: Boolean,
        ): Boolean {
            val intent = Intent(context, OngoingCallService::class.java)
                .setAction(action)
                .putExtra(EXTRA_REQUEST_ID, requestId)
                .putExtra(EXTRA_CALL_ID, callId)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_SUBTITLE, subtitle)
                .putExtra(EXTRA_SCREEN_SHARING, screenSharing)
                .putExtra(EXTRA_CONNECTED, connected)
            try {
                ContextCompat.startForegroundService(context, intent)
                return true
            } catch (error: Exception) {
                Log.w(TAG, "$action failed", error)
                return false
            }
        }
    }
}
