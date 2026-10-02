package com.hiennv.flutter_callkit_incoming

import android.telecom.CallAudioState

/**
 * Telecom's audio state for a hosted call, handed to the app.
 *
 * Telecom tells only the [CallkitConnection] which routes exist (earpiece,
 * speaker, wired, each Bluetooth device) and which one is in use — a headset
 * connected mid-call arrives here and nowhere else the app can see. Signal's
 * `TelecomCallController` collects the same two facts (available endpoints,
 * current endpoint) from Core Telecom. Copied into the plugin by
 * `android/patches/callkit-lifecycle.gradle`.
 */
object CallkitAudioRoutes {
    fun interface Listener {
        fun onCallAudioStateChanged(callId: String, state: CallAudioState)
    }

    @Volatile
    var listener: Listener? = null

    fun changed(callId: String, state: CallAudioState?) {
        if (state != null) listener?.onCallAudioStateChanged(callId, state)
    }
}
