package com.ababilx.call_ringer

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.provider.Settings
import android.util.Log

// What the device says about ringing: which tone to play, and whether it may
// be heard at all. Kept beside [CallRinger] so that object stays about holders
// and player lifecycle.

private const val TAG = "RingtoneSource"

/**
 * Ringtone sources, best first — **every one of them is a ringtone**.
 *
 * The notification default used to sit second in this list, and that is what
 * made an incoming call chime like a new message on some handsets: a phone
 * whose ringtone is set to "None", or whose OEM ROM makes
 * `getActualDefaultRingtoneUri` return null or throw, fell straight through to
 * it. Signal's `IncomingRinger` never does that — when it cannot build a
 * player it rings with nothing and vibrates instead — so the notification tone
 * is gone from here for good. Do not put it back.
 *
 * The middle two candidates exist for the ROMs that break the first one:
 * `Settings.System.RINGTONE` is the same value read without going through
 * `RingtoneManager`, and `getDefaultUri` is the system-wide default rather
 * than this user's pick.
 */
fun ringtoneCandidates(context: Context): List<Uri> {
    val uris = mutableListOf<Uri>()

    // 1. What the user actually chose. Throws on some Samsung/custom-ROM
    //    setups, returns null when the ringtone is "None".
    try {
        RingtoneManager.getActualDefaultRingtoneUri(
            context,
            RingtoneManager.TYPE_RINGTONE,
        )?.let(uris::add)
    } catch (error: Exception) {
        Log.w(TAG, "getActualDefaultRingtoneUri failed", error)
    }

    // 2. The same setting read directly — the public-API equivalent of the
    //    reflection dance Signal's RingtoneUtil falls back to when the call
    //    above is the thing that is broken.
    try {
        Settings.System.getString(context.contentResolver, Settings.System.RINGTONE)
            ?.takeIf { it.isNotBlank() }
            ?.let { uris.add(Uri.parse(it)) }
    } catch (error: Exception) {
        Log.w(TAG, "Settings.System.RINGTONE read failed", error)
    }

    // 3. The device-wide default ringtone, for a profile whose own pick is
    //    unset or points at media this app may not read.
    try {
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)?.let(uris::add)
    } catch (error: Exception) {
        Log.w(TAG, "getDefaultUri(TYPE_RINGTONE) failed", error)
    }

    // 4. Ours, bundled — the last resort, and still a ringtone.
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
