package com.ababilx.app.mediasend

import android.app.Activity
import android.os.Build
import android.window.OnBackInvokedDispatcher

/**
 * Routes the system Back gesture to [MediaSendNavigator.back] on every
 * Android version.
 *
 * On Android 16, an app targeting API 36 gets predictive back by default:
 * `onBackPressed()` is no longer called at all and Back simply finishes the
 * Activity. Every screen in this flow walks its own back stack (editor →
 * review → grid, album → album list, camera → where it was opened from), so
 * without this callback a single Back threw the whole flow away — and a
 * second one, meant for the flow, left the app. The callback is registered
 * for the Activity's whole life because [MediaSendNavigator.back] handles
 * every case, ending in cancel. Below API 33 `onBackPressed` still does it.
 */
object MediaSendBack {

    fun install(activity: Activity, onBack: () -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        activity.onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
        ) { onBack() }
    }
}
