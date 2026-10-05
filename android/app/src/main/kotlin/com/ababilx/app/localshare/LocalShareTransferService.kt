package com.ababilx.app.localshare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Keeps the process, the CPU and the Wi-Fi radio alive while a Local Share
 * transfer is moving bytes.
 *
 * The transfer itself runs in Dart, in the app's own process. Without a
 * foreground service Android freezes that process shortly after the user
 * leaves the app, and a large file died about a minute in. This service does
 * no work of its own: it exists for exactly as long as bytes are moving
 * (Dart's `ShareTransferWatch` starts and stops it) and shows the one
 * notification the system requires for that.
 *
 * `dataSync` is the type for a user-started upload or download. Android 15
 * caps it at six hours a day and then calls [onTimeout]; the service stops
 * and the transfer carries on for as long as the app stays on screen.
 */
class LocalShareTransferService : Service() {
    private var wake: PowerManager.WakeLock? = null
    private var wifi: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(), type)
        } catch (e: Exception) {
            // Refused (started from the background on Android 12+): the
            // transfer still runs while the app is visible.
            Log.w(TAG, "foreground refused: $e")
            stopSelf()
            return START_NOT_STICKY
        }
        holdLocks()
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    override fun onDestroy() {
        runCatching { wake?.takeIf { it.isHeld }?.release() }
        runCatching { wifi?.takeIf { it.isHeld }?.release() }
        super.onDestroy()
    }

    private fun holdLocks() {
        if (wake?.isHeld == true) return
        runCatching {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wake = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ababilx:local-share")
                .apply { acquire(MAX_HOLD_MS) }
            val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifi = manager.createWifiLock(mode, "ababilx:local-share").apply { acquire() }
        }
    }

    private fun notification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Local Share transfers",
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
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle("Local Share")
            .setContentText("Transferring over Wi-Fi")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(0, 0, true)
            .setContentIntent(open)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()
    }

    companion object {
        private const val TAG = "LocalShare"
        private const val CHANNEL_ID = "local_share_transfer"
        private const val NOTIFICATION_ID = 41207
        private const val MAX_HOLD_MS = 6L * 60 * 60 * 1000

        fun start(context: Context) {
            runCatching {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, LocalShareTransferService::class.java),
                )
            }.onFailure { Log.w(TAG, "start refused: $it") }
        }

        fun stop(context: Context) {
            runCatching {
                context.stopService(Intent(context, LocalShareTransferService::class.java))
            }
        }
    }
}
