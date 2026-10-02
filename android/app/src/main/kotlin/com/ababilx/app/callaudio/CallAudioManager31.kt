package com.ababilx.app.callaudio

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Android 12+: Signal's `FullSignalAudioManagerApi31`, ported.
 *
 * The device list is `availableCommunicationDevices`, so Bluetooth needs no
 * Bluetooth permission and no SCO juggling — the reason Signal wrote it. An
 * [AudioDeviceCallback] re-runs the choice whenever a device comes or goes,
 * which is what makes a headset connected mid-call take the call. A
 * communication device that moves off the user's choice is put back
 * (`OnCommunicationDeviceChangedListener`), as Signal does.
 */
@RequiresApi(Build.VERSION_CODES.S)
class CallAudioManager31(context: Context, listener: Listener) : CallAudioManager(context, listener) {

    private var defaultAudioDevice = CallAudioDevice.EARPIECE
    private var userSelectedAudioDevice: AudioDeviceInfo? = null
    private var appliedCommunicationDeviceId: Int? = null

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) = updateAudioDeviceState()
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) = updateAudioDeviceState()
    }

    private val communicationDeviceListener = AudioManager.OnCommunicationDeviceChangedListener { device ->
        Log.i(TAG, "communication device: ${describe(device)} state: $state")
        val chosen = userSelectedAudioDevice
        if (device != null && state == State.RUNNING && chosen != null && device.id != chosen.id) {
            Log.w(TAG, "moved to ${device.id} but user selected ${chosen.id}; re-asserting")
            updateAudioDeviceState()
        }
    }

    private val modeListener = AudioManager.OnModeChangedListener { mode ->
        Log.i(TAG, "mode changed: ${modeName(mode)} state: $state")
    }

    override fun start() {
        if (state == State.RUNNING) return
        savedMode = audio.mode
        savedMicMute = audio.isMicrophoneMute
        Log.i(TAG, "start: savedMode: ${modeName(savedMode)}")
        requestCallAudioFocus()
        setMicrophoneMute(false)
        audio.registerAudioDeviceCallback(deviceCallback, handler)
        audio.addOnModeChangedListener(handler::post, modeListener)
        audio.addOnCommunicationDeviceChangedListener(handler::post, communicationDeviceListener)
        setMode(AudioManager.MODE_IN_COMMUNICATION, "start")
        state = State.RUNNING
        updateAudioDeviceState()
    }

    override fun stop() {
        if (state == State.UNINITIALIZED) return
        Log.i(TAG, "stop: restoring ${modeName(savedMode)}")
        audio.unregisterAudioDeviceCallback(deviceCallback)
        audio.removeOnModeChangedListener(modeListener)
        audio.removeOnCommunicationDeviceChangedListener(communicationDeviceListener)
        audio.clearCommunicationDevice()
        setMicrophoneMute(savedMicMute)
        setMode(savedMode, "stop")
        abandonCallAudioFocus()
        state = State.UNINITIALIZED
        userSelectedAudioDevice = null
        appliedCommunicationDeviceId = null
    }

    override fun setDefaultAudioDevice(device: CallAudioDevice, clearUserEarpieceSelection: Boolean) {
        defaultAudioDevice = when (device) {
            CallAudioDevice.SPEAKER_PHONE -> device
            CallAudioDevice.EARPIECE -> if (hasEarpiece()) device else CallAudioDevice.SPEAKER_PHONE
            else -> throw IllegalArgumentException("Invalid default audio device $device")
        }
        val userType = userSelectedAudioDevice?.let { CallAudioDevice.fromPlatformType(it.type) }
        if (clearUserEarpieceSelection && userType == CallAudioDevice.EARPIECE) {
            userSelectedAudioDevice = null
        }
        Log.i(TAG, "default: $defaultAudioDevice user: ${describe(userSelectedAudioDevice)}")
        updateAudioDeviceState()
    }

    override fun selectAudioDevice(id: Int) {
        userSelectedAudioDevice = audio.availableCommunicationDevices.find { it.id == id }
        Log.i(TAG, "selectAudioDevice($id) -> ${describe(userSelectedAudioDevice)}")
        updateAudioDeviceState()
    }

    private fun updateAudioDeviceState() {
        if (state != State.RUNNING) return
        val current = audio.communicationDevice
        val available = audio.availableCommunicationDevices
        Log.i(TAG, "update: default: $defaultAudioDevice user: ${describe(userSelectedAudioDevice)} " +
            "current: ${describe(current)} available: ${available.joinToString { describe(it) }}")

        if (userSelectedAudioDevice != null && available.none { it.id == userSelectedAudioDevice?.id }) {
            Log.w(TAG, "user selection ${describe(userSelectedAudioDevice)} gone; clearing")
            userSelectedAudioDevice = null
        }

        var candidate = userSelectedAudioDevice
        if (candidate != null && !setCommunicationDeviceIfNeeded(candidate, current)) {
            userSelectedAudioDevice = null
            candidate = null
        }
        if (candidate == null) {
            val order = listOf(
                CallAudioDevice.BLUETOOTH,
                CallAudioDevice.WIRED_HEADSET,
                defaultAudioDevice,
                CallAudioDevice.EARPIECE,
                CallAudioDevice.SPEAKER_PHONE,
            ).distinct()
            val eligible = available.filterNot { it.productName.contains(" Watch", ignoreCase = true) }
            candidate = order.firstNotNullOfOrNull { kind ->
                eligible.find { CallAudioDevice.fromPlatformType(it.type) == kind }
            }
            if (candidate == null) {
                Log.e(TAG, "no suitable device in ${available.joinToString { describe(it) }}")
                audio.clearCommunicationDevice()
                appliedCommunicationDeviceId = null
            } else if (!setCommunicationDeviceIfNeeded(candidate, current)) {
                candidate = null
            }
        }
        publish(snapshot(candidate, available))
    }

    private fun setCommunicationDeviceIfNeeded(device: AudioDeviceInfo, current: AudioDeviceInfo?): Boolean {
        if (device.id == appliedCommunicationDeviceId && device.id == current?.id) return true
        val result = runCatching { audio.setCommunicationDevice(device) }.getOrDefault(false)
        Log.i(TAG, "setCommunicationDevice(${describe(device)}) returned $result")
        if (result) appliedCommunicationDeviceId = device.id
        return result
    }

    /** Signal's picker list: one row per kind, NONE left out. */
    private fun snapshot(active: AudioDeviceInfo?, available: List<AudioDeviceInfo>): CallAudioSnapshot {
        val options = available
            .map { CallAudioOption(CallAudioDevice.fromPlatformType(it.type), it.id, it.productName?.toString().orEmpty(), detail(it.type)) }
            .distinctBy { it.device }
            .filterNot { it.device == CallAudioDevice.NONE }
        val activeKind = active?.let { CallAudioDevice.fromPlatformType(it.type) } ?: CallAudioDevice.NONE
        val activeId = options.firstOrNull { it.device == activeKind }?.id ?: -1
        return CallAudioSnapshot(activeKind, activeId, options)
    }

    private fun detail(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired_headphones"
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired_headset"
        AudioDeviceInfo.TYPE_USB_HEADSET -> "usb_headset"
        else -> ""
    }

    private fun describe(device: AudioDeviceInfo?): String =
        device?.let { "${it.id}:${it.type}:${it.productName}" } ?: "null"
}
