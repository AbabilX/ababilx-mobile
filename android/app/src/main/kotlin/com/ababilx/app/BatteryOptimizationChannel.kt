package com.ababilx.app

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the background restrictions Android has this app under.
 *
 * Read-only on purpose. The exemption itself is still requested through
 * `permission_handler`, which runs the system dialog as an activity result and
 * so can report what the user chose; a `startActivity` from here would launch
 * the same dialog and then have nothing to say about the outcome.
 *
 * See [BatteryState] for why the single "am I exempt?" bit was not enough.
 */
class BatteryOptimizationChannel(private val activity: Activity) {

    private var methods: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        methods = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(::onMethodCall)
        }
    }

    fun dispose() {
        methods?.setMethodCallHandler(null)
        methods = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(BatteryState.snapshot(activity))
            "openSettings" -> result.success(BatteryState.openSettings(activity))
            "openDataSaverSettings" ->
                result.success(BatteryState.openDataSaverSettings(activity))
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.ababilx.app/battery"
    }
}
