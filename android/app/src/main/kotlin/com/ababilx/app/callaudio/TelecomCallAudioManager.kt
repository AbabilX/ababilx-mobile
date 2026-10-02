package com.ababilx.app.callaudio

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.os.Build
import android.telecom.CallAudioState
import android.util.Log
import androidx.annotation.RequiresApi
import com.hiennv.flutter_callkit_incoming.CallkitAudioRoutes
import com.hiennv.flutter_callkit_incoming.CallkitConnection

/**
 * A call Android Telecom is hosting — Signal's `TelecomAudioManager`.
 *
 * flutter_callkit_incoming hosts every ring it shows as a self-managed Telecom
 * call, and answering makes it active. From then on Telecom owns the audio
 * mode, focus and routing, and moves the call to a headset by itself when one
 * connects; Android applies only the mode owner's route, so anything this app
 * sets on `AudioManager` is dropped. This manager therefore sets nothing on
 * `AudioManager` except the microphone mute: it reports Telecom's routes
 * ([CallkitAudioRoutes]) and forwards the user's choice to the [CallkitConnection].
 */
@RequiresApi(Build.VERSION_CODES.O)
@Suppress("DEPRECATION")
class TelecomCallAudioManager(
    context: Context,
    listener: Listener,
    private val connection: CallkitConnection,
) : CallAudioManager(context, listener) {

    private var bluetoothDevices: List<BluetoothDevice> = emptyList()

    override fun start() {
        if (state == State.RUNNING) return
        savedMicMute = audio.isMicrophoneMute
        setMicrophoneMute(false)
        state = State.RUNNING
        CallkitAudioRoutes.listener = CallkitAudioRoutes.Listener { callId, audioState ->
            if (callId == connection.callId) post { onRoutes(audioState) }
        }
        Log.i(TAG, "telecom start: mode ${modeName(audio.mode)} left to Telecom")
        connection.callAudioState?.let { onRoutes(it) }
    }

    override fun stop() {
        if (state == State.UNINITIALIZED) return
        state = State.UNINITIALIZED
        if (CallkitAudioRoutes.listener != null) CallkitAudioRoutes.listener = null
        setMicrophoneMute(savedMicMute)
    }

    /** Signal: an external device in use is kept; EARPIECE is Telecom's own default. */
    override fun setDefaultAudioDevice(device: CallAudioDevice, clearUserEarpieceSelection: Boolean) {
        val current = snapshot?.active
        if (current == CallAudioDevice.BLUETOOTH || current == CallAudioDevice.WIRED_HEADSET) return
        if (device == CallAudioDevice.EARPIECE) return
        route(CallAudioState.ROUTE_SPEAKER)
    }

    override fun selectAudioDevice(id: Int) {
        if (id >= BLUETOOTH_ID_BASE) {
            val device = bluetoothDevices.getOrNull(id - BLUETOOTH_ID_BASE)
            if (device != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                Log.i(TAG, "telecom: requestBluetoothAudio")
                connection.requestBluetoothAudio(device)
                return
            }
            route(CallAudioState.ROUTE_BLUETOOTH)
            return
        }
        route(id)
    }

    private fun route(route: Int) {
        Log.i(TAG, "telecom: setAudioRoute($route)")
        connection.setAudioRoute(route)
    }

    private fun onRoutes(audioState: CallAudioState) {
        if (state != State.RUNNING) return
        val mask = audioState.supportedRouteMask
        Log.i(TAG, "telecom routes: $audioState")
        val options = mutableListOf<CallAudioOption>()
        if (mask and CallAudioState.ROUTE_EARPIECE != 0) {
            options += CallAudioOption(CallAudioDevice.EARPIECE, CallAudioState.ROUTE_EARPIECE)
        }
        if (mask and CallAudioState.ROUTE_SPEAKER != 0) {
            options += CallAudioOption(CallAudioDevice.SPEAKER_PHONE, CallAudioState.ROUTE_SPEAKER)
        }
        if (mask and CallAudioState.ROUTE_WIRED_HEADSET != 0) {
            options += CallAudioOption(CallAudioDevice.WIRED_HEADSET, CallAudioState.ROUTE_WIRED_HEADSET, detail = "wired_headset")
        }
        bluetoothDevices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            audioState.supportedBluetoothDevices.toList()
        } else {
            emptyList()
        }
        if (mask and CallAudioState.ROUTE_BLUETOOTH != 0) {
            if (bluetoothDevices.isEmpty()) {
                options += CallAudioOption(CallAudioDevice.BLUETOOTH, CallAudioState.ROUTE_BLUETOOTH)
            } else {
                bluetoothDevices.forEachIndexed { index, device ->
                    options += CallAudioOption(CallAudioDevice.BLUETOOTH, BLUETOOTH_ID_BASE + index, nameOf(device))
                }
            }
        }
        val active = when (audioState.route) {
            CallAudioState.ROUTE_EARPIECE -> CallAudioDevice.EARPIECE
            CallAudioState.ROUTE_SPEAKER -> CallAudioDevice.SPEAKER_PHONE
            CallAudioState.ROUTE_WIRED_HEADSET -> CallAudioDevice.WIRED_HEADSET
            CallAudioState.ROUTE_BLUETOOTH -> CallAudioDevice.BLUETOOTH
            else -> CallAudioDevice.NONE
        }
        val activeId = activeBluetoothId(audioState)
            ?: options.firstOrNull { it.device == active }?.id ?: -1
        publish(CallAudioSnapshot(active, activeId, options))
    }

    private fun activeBluetoothId(audioState: CallAudioState): Int? {
        if (audioState.route != CallAudioState.ROUTE_BLUETOOTH || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        val index = bluetoothDevices.indexOf(audioState.activeBluetoothDevice ?: return null)
        return if (index >= 0) BLUETOOTH_ID_BASE + index else null
    }

    /** The name needs BLUETOOTH_CONNECT on 12+; refused, the row says "Bluetooth". */
    @SuppressLint("MissingPermission")
    private fun nameOf(device: BluetoothDevice): String = runCatching { device.name }.getOrNull().orEmpty()

    private companion object {
        /** Above every `CallAudioState.ROUTE_*` value, so the two never collide. */
        const val BLUETOOTH_ID_BASE = 1000
    }
}
