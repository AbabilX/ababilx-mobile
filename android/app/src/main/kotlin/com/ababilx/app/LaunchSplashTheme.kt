package com.ababilx.app

import android.app.Activity
import android.content.res.Resources
import android.os.Build

/**
 * Signal's `SplashScreenUtil`: the Android 12+ splash follows the theme
 * picked inside the app, not only the OS one. The system applies it from the
 * NEXT cold start, so it is set on every launch from the stored choice.
 *
 * The choice is Dart's `ThemeModeStore` (`ababilx_theme_mode`), written
 * through shared_preferences' legacy store: file `FlutterSharedPreferences`,
 * keys prefixed `flutter.`. No value or "system" follows the OS (values-night).
 */
object LaunchSplashTheme {
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.ababilx_theme_mode"

    fun apply(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val choice = try {
            activity.getSharedPreferences(PREFS, Activity.MODE_PRIVATE).getString(KEY, null)
        } catch (_: Exception) {
            null
        }
        val theme = when (choice) {
            "light" -> R.style.LaunchTheme_Light
            "dark" -> R.style.LaunchTheme_Dark
            else -> Resources.ID_NULL
        }
        try {
            activity.splashScreen.setSplashScreenTheme(theme)
        } catch (_: Exception) {
            // A splash that follows the OS is the fallback, never a crash.
        }
    }
}
