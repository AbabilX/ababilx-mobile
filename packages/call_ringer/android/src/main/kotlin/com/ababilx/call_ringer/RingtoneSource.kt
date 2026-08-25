package com.ababilx.call_ringer

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri

// What the device says about ringing: which tone to play, and whether it may
// be heard at all. Kept beside [CallRinger] so that object stays about holders
// and player lifecycle.

/**
 * Ringtone sources, best first: whatever the user picked as their phone
 * ringtone, then the notification default, then the bundled app tone —
 * `getActualDefaultRingtoneUri` returns null on a device configured with
 * "None" and throws on some OEM custom-ringtone setups.
 */
fun ringtoneCandidates(context: Context): List<Uri> {
    val uris = mutableListOf<Uri>()
    try {
        RingtoneManager.getActualDefaultRingtoneUri(
            context,
            RingtoneManager.TYPE_RINGTONE,
        )?.let(uris::add)
    } catch (_: Exception) {
    }
    try {
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?.let(uris::add)
    } catch (_: Exception) {
    }
    val bundled = context.resources.getIdentifier(
        "clear_agenda",
        "raw",
        context.packageName,
    )
    if (bundled != 0) {
        uris.add(Uri.parse("android.resource://${context.packageName}/$bundled"))
    }
    return uris.distinct()
}

/** Sound only in normal ringer mode — silent and vibrate stay quiet. */
fun audioAllowed(context: Context): Boolean {
    val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        ?: return true
    if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return false
    return audio.getStreamVolume(AudioManager.STREAM_RING) > 0
}

/**
 * Whether the user would see an incoming call at all. The CallKit surface is a
 * notification, so with notifications off there is nothing to answer or
 * silence — see `CallRinger.hold`.
 */
fun notificationsEnabled(context: Context): Boolean {
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
        as? NotificationManager ?: return true
    return manager.areNotificationsEnabled()
}
