package com.ababilx.call_ringer

import android.util.Log

/**
 * The call this process is in — placing, answering or talking — or none.
 *
 * Signal's rule, from `IdleActionProcessor`: only an idle phone may ring.
 * Every other state answers a new offer with "busy", and accepting stops the
 * ringer outright (`SignalAudioManager.onPrepareForAccept`). Here the call
 * lives in the UI isolate while a push can ring from the FCM isolate, which
 * sees none of that state — so the fact is kept in the process, the one place
 * both reach. Without it a late or repeated `voice_call` push rang again over
 * a call already being talked on, and raised a second ringing screen for it.
 */
object LiveCall {

    private const val TAG = "CallRinger"

    @Volatile
    var id: String? = null
        private set

    /**
     * Enter or leave a call ([callId] null = idle). Entering stops the ring at
     * once, whoever holds it: the call this phone answered must not keep
     * ringing under the conversation.
     */
    fun set(callId: String?) {
        val next = callId?.takeIf { it.isNotEmpty() }
        if (next == id) return
        // Set before releasing: a hold racing this either sees the call and
        // is refused, or got in first and is released below.
        id = next
        Log.i(TAG, "live call ${next ?: "none"}")
        if (next != null) CallRinger.releaseAll()
    }

    /** True (and logged) when [holder] asks to ring during a call. */
    fun refuses(holder: String): Boolean {
        val live = id ?: return false
        Log.i(TAG, "in call $live — not ringing for $holder")
        return true
    }
}
