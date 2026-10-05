package com.ababilx.app.localshare

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `com.ababilx.app/local_share_net`: the Wi-Fi locks Local Share needs.
 *
 * Android filters multicast packets out before an app sees them unless it
 * holds a [WifiManager.MulticastLock] — the manifest permission alone does
 * nothing. Without it a phone announced itself and never heard anyone answer,
 * so discovery worked in one direction only. The lock is held only while
 * discovery runs (Dart releases it when the app leaves the screen): it costs
 * battery, which is why the system makes apps ask.
 *
 * `transferStarted` / `transferEnded` bracket bytes actually moving; they run
 * [LocalShareTransferService], which is what keeps a large file going after
 * the user leaves the app.
 */
class LocalShareNetChannel(private val context: Context) {
    private var multicast: WifiManager.MulticastLock? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> result.success(acquire())
                    "release" -> result.success(release())
                    "transferStarted" -> {
                        LocalShareTransferService.start(context)
                        result.success(null)
                    }
                    "transferEnded" -> {
                        LocalShareTransferService.stop(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquire(): Boolean = runCatching {
        if (multicast?.isHeld == true) return true
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return false
        multicast = wifi.createMulticastLock(TAG).apply {
            // One lock, however many times Dart asks.
            setReferenceCounted(false)
            acquire()
        }
        true
    }.getOrDefault(false)

    private fun release(): Boolean = runCatching {
        multicast?.takeIf { it.isHeld }?.release()
        multicast = null
        true
    }.getOrDefault(false)

    private companion object {
        const val CHANNEL = "com.ababilx.app/local_share_net"
        const val TAG = "ababilx:local-share-discovery"
    }
}
