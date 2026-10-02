package com.ababilx.app.callaudio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.util.Log

/**
 * Below Android 12: Signal's `FullSignalAudioManager`, ported.
 *
 * Keeps the set of devices — speaker always, Bluetooth while a headset is
 * connected ([CallBluetoothManager]), wired while one is plugged in
 * (`ACTION_HEADSET_PLUG`), earpiece otherwise — and picks the user's choice,
 * then the default, then the speaker. A wired headset or a Bluetooth headset
 * that appears takes the call once; choosing something else while it stays
 * connected sticks until it is disconnected and connected again.
 */
@Suppress("DEPRECATION")
class CallAudioManagerLegacy(context: Context, listener: Listener) :
    CallAudioManager(context, listener), CallBluetoothManager.Listener {

    private val bluetooth = CallBluetoothManager(context, this, handler)

    private var audioDevices = mutableSetOf<CallAudioDevice>()
    private var selectedAudioDevice = CallAudioDevice.NONE
    private var defaultAudioDevice = CallAudioDevice.EARPIECE
    private var userSelectedAudioDevice = CallAudioDevice.NONE

    private var savedSpeakerOn = false
    private var hasWiredHeadset = false
    private var autoSwitchToWiredHeadset = true
    private var autoSwitchToBluetooth = true
    private var wiredHeadsetReceiver: BroadcastReceiver? = null

    override fun start() {
        if (state == State.RUNNING) return
        savedMode = audio.mode
        savedSpeakerOn = audio.isSpeakerphoneOn
        savedMicMute = audio.isMicrophoneMute
        hasWiredHeadset = wiredHeadsetOn()
        requestCallAudioFocus()
        setMicrophoneMute(false)
        audioDevices.clear()
        bluetooth.start()
        wiredHeadsetReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val plugged = intent.getIntExtra("state", 0) == 1
                handler.post {
                    Log.i(TAG, "wired headset plugged: $plugged")
                    hasWiredHeadset = plugged
                    onAudioDeviceUpdated()
                }
            }
        }
        context.registerReceiver(wiredHeadsetReceiver, IntentFilter(AudioManager.ACTION_HEADSET_PLUG))
        setMode(AudioManager.MODE_IN_COMMUNICATION, "start")
        state = State.RUNNING
        onAudioDeviceUpdated()
    }

    override fun stop() {
        if (state == State.UNINITIALIZED) return
        state = State.UNINITIALIZED
        wiredHeadsetReceiver?.let { runCatching { context.unregisterReceiver(it) } }
        wiredHeadsetReceiver = null
        bluetooth.stop()
        setSpeakerphoneOn(savedSpeakerOn)
        setMicrophoneMute(savedMicMute)
        setMode(savedMode, "stop")
        abandonCallAudioFocus()
    }

    override fun onAudioDeviceUpdated() {
        if (state != State.RUNNING) return
        Log.i(TAG, "update: wired: $hasWiredHeadset bt: ${bluetooth.state} available: $audioDevices " +
            "selected: $selectedAudioDevice user: $userSelectedAudioDevice")
        if (bluetooth.state.shouldUpdate()) bluetooth.updateDevice()

        val next = mutableSetOf(CallAudioDevice.SPEAKER_PHONE)
        if (bluetooth.state.hasDevice()) next += CallAudioDevice.BLUETOOTH
        if (hasWiredHeadset) {
            next += CallAudioDevice.WIRED_HEADSET
        } else {
            autoSwitchToWiredHeadset = true
            if (hasEarpiece()) next += CallAudioDevice.EARPIECE
        }
        var setChanged = audioDevices != next
        audioDevices = next

        val btState = bluetooth.state
        if (btState == CallBluetoothManager.State.UNAVAILABLE && userSelectedAudioDevice == CallAudioDevice.BLUETOOTH) {
            userSelectedAudioDevice = CallAudioDevice.NONE
        }
        if (hasWiredHeadset && autoSwitchToWiredHeadset) {
            userSelectedAudioDevice = CallAudioDevice.WIRED_HEADSET
            autoSwitchToWiredHeadset = false
        }
        if (!hasWiredHeadset && userSelectedAudioDevice == CallAudioDevice.WIRED_HEADSET) {
            userSelectedAudioDevice = CallAudioDevice.NONE
        }

        val wantsBluetooth = userSelectedAudioDevice == CallAudioDevice.NONE ||
            userSelectedAudioDevice == CallAudioDevice.BLUETOOTH || autoSwitchToBluetooth
        val needStart = btState == CallBluetoothManager.State.AVAILABLE && wantsBluetooth && !audio.isBluetoothScoOn
        val needStop = (btState == CallBluetoothManager.State.CONNECTED || btState == CallBluetoothManager.State.CONNECTING) &&
            userSelectedAudioDevice != CallAudioDevice.NONE && userSelectedAudioDevice != CallAudioDevice.BLUETOOTH
        if (needStop) {
            bluetooth.stopScoAudio()
            bluetooth.updateDevice()
        }
        if (!autoSwitchToBluetooth && bluetooth.state == CallBluetoothManager.State.UNAVAILABLE) {
            autoSwitchToBluetooth = true
        }
        if (needStart && !needStop && !bluetooth.startScoAudio()) {
            audioDevices.remove(CallAudioDevice.BLUETOOTH)
            setChanged = true
        }
        if (autoSwitchToBluetooth && bluetooth.state == CallBluetoothManager.State.CONNECTED) {
            userSelectedAudioDevice = CallAudioDevice.BLUETOOTH
            autoSwitchToBluetooth = false
        }

        val device = when {
            userSelectedAudioDevice in audioDevices -> userSelectedAudioDevice
            defaultAudioDevice in audioDevices -> defaultAudioDevice
            else -> CallAudioDevice.SPEAKER_PHONE
        }
        if (device != selectedAudioDevice || setChanged) {
            setSpeakerphoneOn(device == CallAudioDevice.SPEAKER_PHONE)
            selectedAudioDevice = device
            Log.i(TAG, "available: $audioDevices selected: $device")
        }
        publish(snapshot())
    }

    override fun setDefaultAudioDevice(device: CallAudioDevice, clearUserEarpieceSelection: Boolean) {
        defaultAudioDevice = when (device) {
            CallAudioDevice.SPEAKER_PHONE -> device
            CallAudioDevice.EARPIECE -> if (hasEarpiece()) device else CallAudioDevice.SPEAKER_PHONE
            else -> throw IllegalArgumentException("Invalid default audio device $device")
        }
        if (clearUserEarpieceSelection && userSelectedAudioDevice == CallAudioDevice.EARPIECE) {
            userSelectedAudioDevice = CallAudioDevice.NONE
        }
        onAudioDeviceUpdated()
    }

    override fun selectAudioDevice(id: Int) {
        val mapped = CallAudioDevice.entries.getOrNull(id) ?: return
        // An earpiece press with a wired headset in means the headset, as in Signal.
        userSelectedAudioDevice = if (mapped == CallAudioDevice.EARPIECE && CallAudioDevice.WIRED_HEADSET in audioDevices) {
            CallAudioDevice.WIRED_HEADSET
        } else {
            mapped
        }
        Log.i(TAG, "selectAudioDevice: $mapped -> $userSelectedAudioDevice")
        onAudioDeviceUpdated()
    }

    /** Ids are ordinals; Signal's legacy list starts at the speaker. */
    private fun snapshot(): CallAudioSnapshot {
        val order = listOf(
            CallAudioDevice.SPEAKER_PHONE,
            CallAudioDevice.EARPIECE,
            CallAudioDevice.BLUETOOTH,
            CallAudioDevice.WIRED_HEADSET,
        )
        val options = order.filter { it in audioDevices }.map { device ->
            val name = if (device == CallAudioDevice.BLUETOOTH) bluetooth.deviceName() else ""
            CallAudioOption(device, device.ordinal, name)
        }
        return CallAudioSnapshot(selectedAudioDevice, selectedAudioDevice.ordinal, options)
    }

    private fun setSpeakerphoneOn(on: Boolean) {
        if (audio.isSpeakerphoneOn != on) audio.isSpeakerphoneOn = on
    }

    /** Signal's `isWiredHeadsetOn`: a wired headset or a USB device, input or output. */
    private fun wiredHeadsetOn(): Boolean = audio.getDevices(AudioManager.GET_DEVICES_ALL).any {
        it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET || it.type == AudioDeviceInfo.TYPE_USB_DEVICE
    }
}
