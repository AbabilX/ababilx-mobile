package com.ababilx.app

import android.os.Build
import android.telecom.CallAudioState
import android.telecom.Connection
import com.hiennv.flutter_callkit_incoming.CallkitConnection
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Speaker / earpiece for a call that Android Telecom is hosting.
 *
 * flutter_callkit_incoming registers every ring it shows as a self-managed
 * Telecom call, and Answer on its screen — the lock screen, the heads-up
 * notification — marks that call active. Telecom then sets
 * `MODE_IN_COMMUNICATION` itself, and as a privileged process it becomes the
 * audio-mode owner: AudioService applies the mode owner's route and nobody
 * else's. LiveKit's speaker request comes from this app, so it was dropped
 * without an error and the call stayed on the earpiece whatever the Speaker
 * button said. The plugin's own `setAudioRoute` method is an empty stub.
 *
 * A hosted call is therefore routed through its [Connection], the way Signal
 * routes through its Telecom call. A call Telecom is not hosting — answered
 * in the app, placed from it — answers false and stays with LiveKit.
 */
class CallAudioTelecom {

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "route" -> result.success(
                        route(
                            call.argument<String>("callId").orEmpty(),
                            call.argument<Boolean>("speaker") == true,
                        ),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /** True when Telecom hosts [callId] and has been asked for the route. */
    @Suppress("DEPRECATION")
    private fun route(callId: String, speaker: Boolean): Boolean {
        // The plugin registers its Telecom calls from O on.
        if (callId.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val connection = CallkitConnection.find(callId) ?: return false
        if (connection.state != Connection.STATE_ACTIVE) return false
        // Deprecated on 34 for requestCallEndpointChange, which needs the
        // endpoint list only a Connection subclass is told about — and this
        // one is the plugin's. setAudioRoute still reaches Telecom's router.
        connection.setAudioRoute(routeFor(connection, speaker))
        return true
    }

    /**
     * Off the speaker goes where LiveKit would: a Bluetooth headset first,
     * then a wired one, then the earpiece — WIRED_OR_EARPIECE is the last two.
     */
    @Suppress("DEPRECATION")
    private fun routeFor(connection: Connection, speaker: Boolean): Int {
        if (speaker) return CallAudioState.ROUTE_SPEAKER
        val supported = connection.callAudioState?.supportedRouteMask ?: 0
        return if ((supported and CallAudioState.ROUTE_BLUETOOTH) != 0) {
            CallAudioState.ROUTE_BLUETOOTH
        } else {
            CallAudioState.ROUTE_WIRED_OR_EARPIECE
        }
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/call_audio_telecom"
    }
}
