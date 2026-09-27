package com.hiennv.flutter_callkit_incoming

/**
 * AbabilX: one way to quiet a ringing call, whoever asked.
 *
 * Three doors lead here — Telecom's `Connection.onSilence` (a volume or power
 * key while the phone is ringing, whatever app is in front), a volume key on
 * the full-screen CallKit Activity, and a volume key on MainActivity. The tone
 * itself belongs to the app's `CallRinger`, which this plugin cannot see, so
 * the app installs [handler] at process start (`CallEventBridge.install`).
 * The plugin's own player only carries the vibration by now; it is stopped
 * alongside so a silenced call does not keep buzzing.
 *
 * Deliberately NOT wired to `VOLUME_CHANGED_ACTION`: that broadcast also fires
 * for an OEM increasing-ring ramp, and reacting to it is the original
 * "ring dies two seconds in" bug. Only a key press is a person.
 */
object CallkitRingSilence {
    @Volatile
    var handler: (() -> Unit)? = null

    fun request() {
        handler?.invoke()
        FlutterCallkitIncomingPlugin.getInstance()?.getCallkitSoundPlayerManager()?.stop()
    }
}
