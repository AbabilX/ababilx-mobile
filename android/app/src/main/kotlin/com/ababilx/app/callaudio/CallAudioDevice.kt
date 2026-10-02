package com.ababilx.app.callaudio

import android.media.AudioDeviceInfo
import android.os.Build
import androidx.annotation.RequiresApi

/**
 * Where a call's audio can go. Signal's `SignalAudioManager.AudioDevice`, and
 * the platform-type table is its `AudioDeviceMapping`: a hearing aid and an
 * LE headset count as Bluetooth, a USB headset as wired.
 */
enum class CallAudioDevice(val wire: String) {
    SPEAKER_PHONE("speaker"),
    WIRED_HEADSET("wired"),
    EARPIECE("handset"),
    BLUETOOTH("bluetooth"),
    NONE("none");

    companion object {
        @RequiresApi(Build.VERSION_CODES.S)
        fun fromPlatformType(type: Int): CallAudioDevice = when (type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_HEARING_AID -> BLUETOOTH
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> EARPIECE
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE -> SPEAKER_PHONE
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_USB_HEADSET -> WIRED_HEADSET
            else -> NONE
        }

        fun fromWire(wire: String?): CallAudioDevice? = entries.firstOrNull { it.wire == wire }
    }
}

/**
 * One row of the output picker — Signal's `AudioOutputOption`. [id] is what
 * comes back on selection: an `AudioDeviceInfo` id on API 31+, the device's
 * ordinal below it, a Telecom route under Telecom. [detail] lets Dart name a
 * wired device as Signal does (headphones / headset / USB headset); [name] is
 * the product name, which is what a Bluetooth row shows.
 */
data class CallAudioOption(
    val device: CallAudioDevice,
    val id: Int,
    val name: String = "",
    val detail: String = "",
) {
    fun toMap(): Map<String, Any> = mapOf(
        "type" to device.wire,
        "id" to id,
        "name" to name,
        "detail" to detail,
    )
}

/** What the call is on now, and what it could be on. */
data class CallAudioSnapshot(
    val active: CallAudioDevice,
    val activeId: Int,
    val options: List<CallAudioOption>,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "active" to active.wire,
        "activeId" to activeId,
        "options" to options.map { it.toMap() },
    )
}
