package com.ababilx.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Where a tap on the ongoing-call notification lands, so that a tap on the
 * LOCK SCREEN reaches the call without the PIN pad.
 *
 * SystemUI asks for the PIN before launching a notification's Activity unless
 * the manifest declares that Activity `showWhenLocked` — and MainActivity must
 * never be, or the whole app would open over the lock screen. This one is,
 * holds nothing, and forwards to MainActivity, whose [CallLockScreen] lifts
 * only a live call over the keyguard. flutter_callkit_incoming's
 * TransparentActivity is the same trampoline for Accept.
 */
class CallReturnActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(OngoingCallService.ACTION_RETURN_TO_CALL)
                .putExtra(
                    OngoingCallService.EXTRA_CALL_ID,
                    intent.getStringExtra(OngoingCallService.EXTRA_CALL_ID) ?: "",
                )
                // The task already holding the call, never a second engine;
                // CLEAR_TOP also closes a media picker left open above it.
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
        )
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
