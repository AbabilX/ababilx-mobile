package com.ababilx.call_ringer

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes [CallRinger] to Dart on every engine, including the FCM and CallKit
 * background isolates, which is where a killed app starts and stops ringing.
 */
class CallRingerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    /** This engine entered the live call, so its end takes the call with it. */
    private var ownsLiveCall = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // The call lived in this engine (the Activity's). An engine that is
        // gone is a call that is gone; left set, every later ring would be
        // refused as "busy" until the process died.
        if (ownsLiveCall) LiveCall.set(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Holders are process-wide, so a hold taken in the background isolate
        // is released by the UI isolate (and the other way round) without any
        // state having to survive an isolate.
        val holder = call.argument<String>("holder")
        val requireUi = call.argument<Boolean>("requireNotificationUi") == true
        when (call.method) {
            "hold" -> {
                if (holder == null) return result.badHolder()
                CallRinger.hold(context, holder, requireUi)
                result.success(null)
            }
            "restart" -> {
                if (holder == null) return result.badHolder()
                CallRinger.restart(context, holder, requireUi)
                result.success(null)
            }
            "release" -> {
                if (holder == null) return result.badHolder()
                CallRinger.release(holder)
                result.success(null)
            }
            "releaseAll" -> {
                CallRinger.releaseAll()
                result.success(null)
            }
            "silence" -> result.success(CallRinger.silence())
            "setLiveCall" -> {
                val callId = call.argument<String>("callId")
                ownsLiveCall = !callId.isNullOrEmpty()
                LiveCall.set(callId)
                result.success(null)
            }
            "liveCall" -> result.success(LiveCall.id)
            // Same reason this package exists at all: the CallKit surface has
            // to be closable from whichever engine is alive, background
            // isolate included. See [CallkitSurface] for why the plugin's own
            // dismissal never arrives.
            "dismissCallkitIncoming" -> {
                CallkitSurface.dismissIncoming(
                    context,
                    call.argument<Boolean>("accepted") == true,
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun MethodChannel.Result.badHolder() =
        error("bad_args", "holder is required", null)

    companion object {
        private const val CHANNEL = "com.ababilx.app/call_ringer"
    }
}
