package com.ababilx.app

import android.util.Log

/**
 * The user ended a screen share from outside the app — the status-bar chip,
 * the Cast tile, the shade.
 *
 * flutter_webrtc's MediaProjection callback calls this by reflection (see
 * `android/patches/flutter-webrtc-projection-stop.gradle`); it fires only for
 * a stop the app did not ask for. Dart then tears the share down properly:
 * the track, the sender, the media map, the foreground-service type and, in a
 * group call, the server-side claim.
 */
object ScreenCaptureStop {
    @JvmStatic
    fun onSystemStop() {
        Log.i("ScreenCaptureStop", "screen share stopped from the system")
        OngoingCallBridge.notifyScreenShareStopped()
    }
}
