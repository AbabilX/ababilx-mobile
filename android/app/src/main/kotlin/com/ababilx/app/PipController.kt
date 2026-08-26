package com.ababilx.app

import android.annotation.SuppressLint
import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.util.Rational
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-picture for a live call.
 *
 * Signal's call lives in its own Activity, so backing out of a call there
 * shrinks that Activity into a floating window (`enterPipModeIfPossible`,
 * called from the back handler and from `onUserLeaveHint`). We have one
 * FlutterActivity for the whole app, so the same move works only while the
 * call route is the thing on screen — which is exactly when Dart calls
 * [setActive]. Outside a call PiP stays off, or pressing Home from the chat
 * list would shrink the whole app into a thumbnail.
 *
 * On API 31+ `setAutoEnterEnabled` lets the system animate the transition
 * itself when Home is pressed, which is smoother than reacting to
 * `onUserLeaveHint` after the fact; the manual path stays for older versions
 * and for the back press.
 */
class PipController(private val activity: Activity) : EventChannel.StreamHandler {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    /** True while Dart says a call is on screen and worth shrinking. */
    private var active = false

    fun attach(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(supported())
                    "setActive" -> {
                        active = call.argument<Boolean>("active") ?: false
                        applyParams()
                        result.success(null)
                    }
                    "enter" -> result.success(enter())
                    else -> result.notImplemented()
                }
            }
        }
        eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    fun dispose() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        sink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /** Home pressed. Only shrink if a call is the reason we are on screen. */
    fun onUserLeaveHint() {
        if (!active) return
        // API 31+ already auto-entered via setAutoEnterEnabled.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        enter()
    }

    fun onPipModeChanged(inPip: Boolean) {
        sink?.success(inPip)
    }

    private fun supported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    @SuppressLint("NewApi") // guarded by supported()
    private fun enter(): Boolean {
        if (!supported() || !active) return false
        return try {
            activity.enterPictureInPictureMode(params())
        } catch (error: Exception) {
            // Signal carries the same guard: some devices advertise PiP and
            // then throw. A failed shrink must not take the call down.
            Log.w(TAG, "Device lied about supporting PiP", error)
            false
        }
    }

    @SuppressLint("NewApi") // guarded by supported()
    private fun applyParams() {
        if (!supported()) return
        try {
            activity.setPictureInPictureParams(params())
        } catch (error: Exception) {
            Log.w(TAG, "setPictureInPictureParams failed", error)
        }
    }

    @SuppressLint("NewApi") // only reached from supported() callers
    private fun params(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(active)
            builder.setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    private companion object {
        const val TAG = "PipController"
        const val METHOD_CHANNEL = "com.ababilx.app/pip"
        const val EVENT_CHANNEL = "com.ababilx.app/pip/events"
    }
}
