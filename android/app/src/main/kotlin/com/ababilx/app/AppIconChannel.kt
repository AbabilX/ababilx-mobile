package com.ababilx.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Alternate launcher icons.
 *
 * Android has no API for "change my icon"; the only mechanism is a set of
 * `activity-alias` entries, each carrying its own icon, of which exactly one
 * is enabled. Signal does the same thing, and so does every other app with an
 * icon picker.
 *
 * Two consequences worth knowing, both inherent to the mechanism rather than
 * to this code: the launcher may take a moment to redraw, and some launchers
 * drop a home-screen shortcut that pointed at the alias being disabled.
 *
 * DONT_KILL_APP is passed on every call — without it the system tears the
 * process down mid-switch and the user watches the app vanish.
 */
class AppIconChannel(private val context: Context) {

    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> result.success(current())
                    "set" -> {
                        val id = call.argument<String>("id")
                        if (id == null || !ALIASES.containsKey(id)) {
                            result.error("bad_args", "unknown icon id: $id", null)
                        } else {
                            result.success(apply(id))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    /** The id whose alias is enabled right now. */
    private fun current(): String {
        val manager = context.packageManager
        for ((id, alias) in ALIASES) {
            val state = try {
                manager.getComponentEnabledSetting(component(alias))
            } catch (error: IllegalArgumentException) {
                Log.w(TAG, "alias missing: $alias", error)
                continue
            }
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return id
        }
        // Nothing explicitly enabled means everything is still at its manifest
        // default, and the default alias is the only one enabled there.
        return DEFAULT_ID
    }

    private fun apply(id: String): Boolean {
        val manager = context.packageManager
        // Enable the new one before disabling the old, so there is never an
        // instant with no launcher entry at all.
        val chosen = ALIASES.getValue(id)
        return try {
            manager.setComponentEnabledSetting(
                component(chosen),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for ((otherId, alias) in ALIASES) {
                if (otherId == id) continue
                manager.setComponentEnabledSetting(
                    component(alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            true
        } catch (error: Exception) {
            Log.w(TAG, "could not switch icon to $id", error)
            false
        }
    }

    private fun component(alias: String) =
        ComponentName(context.packageName, "${context.packageName}$alias")

    private companion object {
        const val TAG = "AppIconChannel"
        const val CHANNEL = "com.ababilx.app/app_icon"
        const val DEFAULT_ID = "default"

        /** Visible icons plus hidden aliases retained for safe upgrades. */
        val ALIASES = linkedMapOf(
            DEFAULT_ID to ".Launcher",
            "calendar" to ".LauncherCalendar",
            "notes" to ".LauncherNotes",
            "weather" to ".LauncherWeather",
            "legacy_ink" to ".LauncherInk",
            "legacy_indigo" to ".LauncherIndigo",
            "legacy_forest" to ".LauncherForest",
        )
    }
}
