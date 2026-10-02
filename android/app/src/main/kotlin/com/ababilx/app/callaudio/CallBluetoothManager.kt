package com.ababilx.app.callaudio

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.util.Log

/**
 * Bluetooth headset lifecycle below Android 12: Signal's
 * `SignalBluetoothManager`, ported. It only reports whether a headset is
 * connected and opens / closes SCO when [CallAudioManagerLegacy] asks; the
 * choice of device is not made here. Runs on the call-audio thread.
 */
@SuppressLint("MissingPermission")
@Suppress("DEPRECATION")
class CallBluetoothManager(
    private val context: Context,
    private val listener: Listener,
    private val handler: Handler,
) {
    fun interface Listener {
        fun onAudioDeviceUpdated()
    }

    enum class State {
        UNINITIALIZED, UNAVAILABLE, AVAILABLE, DISCONNECTING, CONNECTING, CONNECTED, PERMISSION_DENIED;

        fun shouldUpdate() = this == AVAILABLE || this == UNAVAILABLE || this == DISCONNECTING
        fun hasDevice() = this == CONNECTED || this == CONNECTING || this == AVAILABLE
    }

    var state = State.UNINITIALIZED
        private set

    private val audio = context.getSystemService(AudioManager::class.java)
    private var adapter: BluetoothAdapter? = null
    private var device: BluetoothDevice? = null
    private var headset: BluetoothHeadset? = null
    private var scoAttempts = 0
    private var receiver: BroadcastReceiver? = null
    private val timeout = Runnable { onBluetoothTimeout() }

    private val serviceListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (profile != BluetoothProfile.HEADSET) return
            handler.post {
                if (state == State.UNINITIALIZED) return@post
                headset = proxy as? BluetoothHeadset
                listener.onAudioDeviceUpdated()
            }
        }

        override fun onServiceDisconnected(profile: Int) {
            if (profile != BluetoothProfile.HEADSET) return
            handler.post {
                if (state == State.UNINITIALIZED) return@post
                stopScoAudio()
                headset = null
                device = null
                state = State.UNAVAILABLE
                listener.onAudioDeviceUpdated()
            }
        }
    }

    fun start() {
        if (state != State.UNINITIALIZED) return
        headset = null
        device = null
        scoAttempts = 0
        adapter = BluetoothAdapter.getDefaultAdapter() ?: return
        if (!audio.isBluetoothScoAvailableOffCall) return
        val proxied = runCatching {
            adapter?.getProfileProxy(context, serviceListener, BluetoothProfile.HEADSET) == true
        }.getOrDefault(false)
        if (!proxied) {
            Log.e(TAG, "getProfileProxy(HEADSET) failed")
            return
        }
        receiver = CallBluetoothReceiver(this, handler).also {
            context.registerReceiver(it, CallBluetoothReceiver.filter())
        }
        state = State.UNAVAILABLE
    }

    fun stop() {
        if (adapter == null) return
        stopScoAudio()
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        receiver = null
        handler.removeCallbacks(timeout)
        headset?.let { adapter?.closeProfileProxy(BluetoothProfile.HEADSET, it) }
        headset = null
        adapter = null
        device = null
        state = State.UNINITIALIZED
    }

    fun startScoAudio(): Boolean {
        if (scoAttempts >= MAX_CONNECTION_ATTEMPTS || state != State.AVAILABLE) return false
        state = State.CONNECTING
        audio.startBluetoothSco()
        audio.isBluetoothScoOn = true
        scoAttempts++
        handler.postDelayed(timeout, SCO_TIMEOUT_MS)
        return true
    }

    fun stopScoAudio() {
        if (state != State.CONNECTING && state != State.CONNECTED) return
        handler.removeCallbacks(timeout)
        audio.stopBluetoothSco()
        audio.isBluetoothScoOn = false
        state = State.DISCONNECTING
    }

    fun updateDevice() {
        if (state == State.UNINITIALIZED || headset == null) return
        val devices = try {
            headset?.connectedDevices
        } catch (e: SecurityException) {
            Log.w(TAG, "no Bluetooth permission", e)
            stop()
            state = State.PERMISSION_DENIED
            return
        }
        if (devices.isNullOrEmpty()) {
            device = null
            state = State.UNAVAILABLE
        } else {
            device = devices[0]
            state = if (headset?.isAudioConnected(device) == true) State.CONNECTED else State.AVAILABLE
        }
    }

    fun deviceName(): String = runCatching { device?.name }.getOrNull().orEmpty()

    private fun onBluetoothTimeout() {
        if (state != State.CONNECTING || headset == null) return
        device = headset?.connectedDevices?.firstOrNull()
        if (device != null && headset?.isAudioConnected(device) == true) {
            state = State.CONNECTED
            scoAttempts = 0
        } else {
            Log.w(TAG, "SCO did not connect in time")
            stopScoAudio()
        }
        listener.onAudioDeviceUpdated()
    }

    internal fun onConnectionStateChanged(connectionState: Int) {
        if (state == State.UNINITIALIZED) return
        if (connectionState == BluetoothHeadset.STATE_CONNECTED) scoAttempts = 0
        if (connectionState == BluetoothHeadset.STATE_DISCONNECTED) stopScoAudio()
        if (connectionState == BluetoothHeadset.STATE_CONNECTED || connectionState == BluetoothHeadset.STATE_DISCONNECTED) {
            listener.onAudioDeviceUpdated()
        }
    }

    /** Audio dropped while the headset stays connected: re-read it, as Signal does. */
    internal fun onAudioStateChanged(audioState: Int, previous: Int, initialSticky: Boolean) {
        if (state == State.UNINITIALIZED) return
        val interrupted = previous == BluetoothHeadset.STATE_AUDIO_CONNECTED &&
            audioState == BluetoothHeadset.STATE_AUDIO_DISCONNECTED && device != null &&
            headset?.getConnectionState(device) == BluetoothProfile.STATE_CONNECTED
        if (interrupted) {
            scoAttempts = 0
            updateDevice()
            return
        }
        if (audioState == BluetoothHeadset.STATE_AUDIO_DISCONNECTED) {
            if (!initialSticky) listener.onAudioDeviceUpdated()
            return
        }
        if (audioState != BluetoothHeadset.STATE_AUDIO_CONNECTED) return
        handler.removeCallbacks(timeout)
        if (state == State.CONNECTING) {
            state = State.CONNECTED
            scoAttempts = 0
            listener.onAudioDeviceUpdated()
        }
    }

    internal fun onScoDisconnected() = listener.onAudioDeviceUpdated()

    private companion object {
        const val TAG = "CallAudio"
        const val SCO_TIMEOUT_MS = 4_000L
        const val MAX_CONNECTION_ATTEMPTS = 2
    }
}
