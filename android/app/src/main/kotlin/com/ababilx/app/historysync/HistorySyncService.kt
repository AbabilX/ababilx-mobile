package com.ababilx.app.historysync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Keeps the process alive while a linked computer reads this phone's chats
 * over a live history link (server 0175, docs/history-live-protocol.md).
 *
 * The answering runs in Dart, in this process. Without a foreground service
 * Android freezes the process shortly after the user locks the phone, and the
 * computer would sit on "Loading from your phone" with nothing coming. Like
 * [com.ababilx.app.localshare.LocalShareTransferService] it does no work of
 * its own: Dart starts it when the data channel opens and stops it when the
 * channel closes or goes idle. A foreground-service process also keeps its
 * network in Doze, which is the other half of the point.
 *
 * `dataSync`: a user-started transfer. Android 15 caps it at six hours a day
 * and then calls [onTimeout]; the link still answers while the app is open.
 */
class HistorySyncService : Service() {
    private var wake: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        val device = intent?.getStringExtra(EXTRA_DEVICE).orEmpty()
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(device), type)
        } catch (e: Exception) {
            // Refused (started from the background on Android 12+): the link
            // still answers while the app is visible.
            Log.w(TAG, "foreground refused: $e")
            stopSelf()
            return START_NOT_STICKY
        }
        if (wake?.isHeld != true) {
            runCatching {
                val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                wake = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ababilx:history-sync")
                    .apply { acquire(MAX_HOLD_MS) }
            }
        }
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    override fun onDestroy() {
        runCatching { wake?.takeIf { it.isHeld }?.release() }
        super.onDestroy()
    }

    private fun notification(device: String): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Linked computer sync",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val icon = resources.getIdentifier("ic_stat_ababilx", "drawable", packageName)
            .takeIf { it != 0 } ?: applicationInfo.icon
        val target = device.ifBlank { "your computer" }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle("Syncing chats")
            .setContentText("Sending messages to $target")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()
    }

    companion object {
        private const val TAG = "HistorySync"
        private const val CHANNEL_ID = "history_sync"
        private const val NOTIFICATION_ID = 41208
        private const val EXTRA_DEVICE = "device"
        private const val MAX_HOLD_MS = 60L * 60 * 1000

        fun start(context: Context, device: String) {
            runCatching {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, HistorySyncService::class.java).putExtra(EXTRA_DEVICE, device),
                )
            }.onFailure { Log.w(TAG, "start refused: $it") }
        }

        fun stop(context: Context) {
            runCatching { context.stopService(Intent(context, HistorySyncService::class.java)) }
        }
    }
}
