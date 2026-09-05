package com.ababilx.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.TelephonyManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Whether this handset is currently roaming.
 *
 * `connectivity_plus` answers Wi-Fi vs mobile and stops there, so without this
 * the "Roaming" auto-download checkbox would be a control that never applies —
 * worse than not offering it, because the user would believe they had turned
 * something off.
 *
 * Two readings, in order of trust:
 *
 *  - [NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING] (API 28+) describes the
 *    network actually carrying traffic, so it is right on a dual-SIM handset
 *    and right when data is on the SIM that is not the voice SIM.
 *  - [TelephonyManager.isNetworkRoaming] is the fallback. It answers for the
 *    default data subscription and needs no permission.
 *
 * Reported false whenever it cannot be read: an unanswerable question must not
 * silently withhold media the user asked to download on cellular.
 */
object NetworkState {

    fun isRoaming(context: Context): Boolean =
        capabilitiesRoaming(context) ?: telephonyRoaming(context)

    /** Null when there is no active network, or on API < 28. */
    private fun capabilitiesRoaming(context: Context): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as? ConnectivityManager ?: return null
        return runCatching {
            val active = connectivity.activeNetwork ?: return null
            val caps = connectivity.getNetworkCapabilities(active) ?: return null
            // Only a cellular transport has a roaming state worth reporting;
            // Wi-Fi always lacks NOT_ROAMING and would read as roaming.
            if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) return false
            !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING)
        }.getOrNull()
    }

    private fun telephonyRoaming(context: Context): Boolean {
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE)
            as? TelephonyManager ?: return false
        return runCatching { telephony.isNetworkRoaming }.getOrDefault(false)
    }
}

/** Read-only bridge for [NetworkState]. */
class NetworkStateChannel(private val context: Context) {

    private var methods: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        methods = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(::onMethodCall)
        }
    }

    fun dispose() {
        methods?.setMethodCallHandler(null)
        methods = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isRoaming" -> result.success(NetworkState.isRoaming(context))
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.ababilx.app/network"
    }
}
