package com.ababilx.app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * What Android is currently doing to this app in the background.
 *
 * `permission_handler` can answer exactly one of these — whether the app is
 * exempt from battery optimizations — and that single bit is not enough to
 * decide whether asking for the exemption would help. Two other OS states
 * change the answer:
 *
 *  - **Data Saver.** With it on, the OS withholds background network from the
 *    app whatever its battery standby bucket says. Prompting for a battery
 *    exemption then trades a scary system dialog for no improvement at all.
 *  - **Background restricted** (`ActivityManager.isBackgroundRestricted`, API
 *    28+). The user, or an OEM's own "battery manager", has put the app in the
 *    harshest bucket there is. The exemption is worth asking for, and worth
 *    saying more about.
 *
 * Read on demand rather than cached: every one of these can be changed from
 * Settings while the app sits in the background.
 */
object BatteryState {

    private const val TAG = "BatteryState"

    const val DATA_SAVER_DISABLED = "disabled"
    const val DATA_SAVER_WHITELISTED = "whitelisted"
    const val DATA_SAVER_ENABLED = "enabled"

    fun snapshot(context: Context): Map<String, Any?> = mapOf(
        "ignoringBatteryOptimizations" to isIgnoringBatteryOptimizations(context),
        "dataSaver" to dataSaverState(context),
        "backgroundRestricted" to isBackgroundRestricted(context),
        "deviceIdle" to isDeviceIdle(context),
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "sdkInt" to Build.VERSION.SDK_INT,
    )

    /**
     * Defaults to `true` — "nothing to fix" — when the service is missing, so a
     * device we cannot read never gets nagged on a guess.
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return runCatching { power.isIgnoringBatteryOptimizations(context.packageName) }
            .getOrDefault(true)
    }

    /** This app's own standing with Data Saver, not the global switch. */
    private fun dataSaverState(context: Context): String {
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as? ConnectivityManager ?: return DATA_SAVER_DISABLED
        return when (runCatching { connectivity.restrictBackgroundStatus }.getOrNull()) {
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED -> DATA_SAVER_ENABLED
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_WHITELISTED -> DATA_SAVER_WHITELISTED
            else -> DATA_SAVER_DISABLED
        }
    }

    private fun isBackgroundRestricted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE)
            as? ActivityManager ?: return false
        return runCatching { activity.isBackgroundRestricted }.getOrDefault(false)
    }

    private fun isDeviceIdle(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return runCatching { power.isDeviceIdleMode }.getOrDefault(false)
    }

    /** The system "allow this app to ignore battery optimizations?" dialog. */
    fun requestIgnoreIntent(context: Context): Intent = Intent(
        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
        Uri.parse("package:${context.packageName}"),
    )

    /**
     * Data Saver's per-app exception list.
     *
     * A separate screen from battery optimization, and a separate problem: with
     * Data Saver applied the OS withholds background network no matter what the
     * battery bucket says, so the battery dialog would grant something that
     * changes nothing.
     */
    fun openDataSaverSettings(context: Context): Boolean = launchFirst(
        context,
        listOf(
            Intent(
                Settings.ACTION_IGNORE_BACKGROUND_DATA_RESTRICTIONS_SETTINGS,
                Uri.parse("package:${context.packageName}"),
            ),
            Intent(Settings.ACTION_DATA_USAGE_SETTINGS),
        ),
    )

    /**
     * Where the user goes when the dialog was refused for good.
     *
     * The battery-optimization list first, app details second. Deliberately no
     * OEM-specific component names (Xiaomi's autostart screen and friends):
     * those Activity names change between ROM builds, are not exported on some,
     * and a stale one throws `ActivityNotFoundException` in the user's face
     * instead of showing them anything.
     */
    fun openSettings(context: Context): Boolean = launchFirst(
        context,
        listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${context.packageName}"),
            ),
        ),
    )

    /**
     * Tried rather than resolved: from API 30 package visibility makes
     * `resolveActivity` return null for screens that do in fact open, so asking
     * first would rule out the good intent on exactly the versions that need it
     * most.
     */
    private fun launchFirst(context: Context, candidates: List<Intent>): Boolean {
        for (intent in candidates) {
            val launched = runCatching {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }.isSuccess
            if (launched) return true
        }
        Log.w(TAG, "no settings screen would open")
        return false
    }
}
