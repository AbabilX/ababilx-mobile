package com.ababilx.app

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine

/**
 * Keeps a live call's FlutterEngine when its Activity goes away.
 *
 * The WebRTC session lives in the Dart isolate, and the isolate lives in the
 * engine. MainActivity used to own that engine outright, so swiping the app
 * out of Recents — or the OS reclaiming the Activity — hung up on the other
 * person. While [OngoingCallService] is in the foreground the engine is parked
 * here instead: the service keeps the process, this keeps the call, and the
 * next MainActivity picks the same engine back up.
 *
 * Only for a live call. With no call the engine dies with its Activity as it
 * always has, and once a parked call ends the engine is destroyed after a
 * short grace so Dart can finish hanging up.
 *
 * Main thread only.
 */
object CallEngineKeeper {

    private const val TAG = "CallEngineKeeper"

    /** Long enough for the hang-up request and the media teardown to finish. */
    private const val END_GRACE_MS = 15_000L

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private val destroy = Runnable { release() }

    /** Parks [kept]; its Activity is being destroyed under a live call. */
    fun keep(kept: FlutterEngine) {
        Log.i(TAG, "keep")
        main.removeCallbacks(destroy)
        engine = kept
    }

    /** The parked engine, handed to the Activity that is starting. */
    fun take(): FlutterEngine? {
        main.removeCallbacks(destroy)
        val kept = engine ?: return null
        Log.i(TAG, "take")
        engine = null
        return kept
    }

    fun onCallStarted() = main.removeCallbacks(destroy)

    /** The call is over; a parked engine has nothing left to carry. */
    fun onCallEnded() {
        if (engine == null) return
        main.removeCallbacks(destroy)
        main.postDelayed(destroy, END_GRACE_MS)
    }

    private fun release() {
        val kept = engine ?: return
        Log.i(TAG, "destroy")
        engine = null
        kept.destroy()
    }
}
