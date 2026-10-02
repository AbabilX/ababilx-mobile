package com.ababilx.app

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import com.ababilx.app.callaudio.CallAudioDevice
import com.ababilx.app.callaudio.CallAudioSession

/**
 * Signal's `WebRtcUtil.getInCallPhoneState`: a call is hands-free — so the
 * screen stays lit, the phone is not at a face — when the speaker or a
 * Bluetooth device carries it, or a wired headset is plugged in. Anything else
 * is `IN_CALL`, and the proximity sensor blanks the screen at the ear.
 *
 * The route comes from the call's own audio owner ([CallAudioSession]): a
 * Bluetooth headset that is merely connected, while the user picked the
 * earpiece, is not hands-free. With no owner running, the platform is asked
 * the way Signal's `AudioManagerCompat` asks it.
 */
object CallHandsFree {

    fun isHandsFree(audio: AudioManager): Boolean {
        if (wiredHeadsetOn(audio)) return true
        val active = CallAudioSession.activeDevice ?: return platformHandsFree(audio)
        return active in HANDS_FREE
    }

    @Suppress("DEPRECATION")
    private fun platformHandsFree(audio: AudioManager): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val device = audio.communicationDevice ?: return@runCatching false
            CallAudioDevice.fromPlatformType(device.type) in HANDS_FREE
        } else {
            audio.isSpeakerphoneOn || audio.isBluetoothScoOn
        }
    }.getOrDefault(false)

    /** Signal's `isWiredHeadsetOn`: a wired headset or USB device present. */
    @Suppress("DEPRECATION")
    private fun wiredHeadsetOn(audio: AudioManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return audio.isWiredHeadsetOn
        return runCatching {
            audio.getDevices(AudioManager.GET_DEVICES_ALL).any { it.type in WIRED_TYPES }
        }.getOrDefault(false)
    }

    private val HANDS_FREE = setOf(
        CallAudioDevice.SPEAKER_PHONE,
        CallAudioDevice.BLUETOOTH,
        CallAudioDevice.WIRED_HEADSET,
    )

    private val WIRED_TYPES = setOf(
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
    )
}
