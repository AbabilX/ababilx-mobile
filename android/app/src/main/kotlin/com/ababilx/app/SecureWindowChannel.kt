package com.ababilx.app

import android.app.Activity
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `FLAG_SECURE` for Ghost Chat: no screenshots, no screen recording, and a
 * blank thumbnail in Recents, for as long as a session is on screen.
 *
 * The wanted state is process-wide, not per Activity. MainActivity can be
 * recreated under a live session (a configuration change, a lock-screen
 * handoff), and the Dart side sends `setSecure` only when the state changes —
 * so a new Activity has to pick the flag back up on its own when it attaches,
 * or the second half of a chat would be capturable.
 *
 * Holds are COUNTED, which is Signal's `TemporaryScreenshotSecurity`: the flag
 * goes up on the first hold and comes down only when the last one is released.
 * Ghost Chat is the only holder today, so the count is always 0 or 1 — but a
 * second feature asking for the same flag must not have its protection cleared
 * by the first one finishing, and that is not a bug worth discovering later.
 */
class SecureWindowChannel(private val activity: Activity) {

    fun attach(engine: FlutterEngine) {
        apply()
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.argument<Boolean>("secure") == true) {
                            holds.incrementAndGet()
                        } else {
                            holds.updateAndGet { held -> maxOf(0, held - 1) }
                        }
                        apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun apply() {
        activity.runOnUiThread {
            if (holds.get() > 0) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/secure_window"

        /** Process-wide, so a recreated Activity re-applies what is still held. */
        val holds = java.util.concurrent.atomic.AtomicInteger(0)
    }
}
