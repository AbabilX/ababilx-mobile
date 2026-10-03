package com.ababilx.app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicLong

/**
 * Where the ongoing-call notification meets Dart.
 *
 * Dart drives the service (`start` / `update` / `stop`) and listens for the
 * two things the user can do from outside the app: press Hang up in the shade,
 * or tap the notification to come back to the call.
 *
 * Engine-scoped, on the application context: a call outlives its Activity
 * (see [CallEngineKeeper]), and Dart must still be able to stop the service —
 * and hear Hang up from the shade — with no Activity at all. MainActivity
 * attaches it once per engine and disposes it only when the engine dies.
 */
class OngoingCallChannel(context: Context) {

    private val context: Context = context.applicationContext

    private var methods: MethodChannel? = null
    private var events: EventChannel? = null

    fun attach(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        methods = MethodChannel(messenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(::onMethodCall)
        }
        events = EventChannel(messenger, EVENT_CHANNEL).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    OngoingCallBridge.attach(sink)
                }

                override fun onCancel(arguments: Any?) {
                    OngoingCallBridge.attach(null)
                }
            })
        }
    }

    fun dispose() {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        OngoingCallBridge.attach(null)
    }

    /**
     * A tap on the ongoing-call notification. Reported rather than routed
     * here: only Dart knows whether that call is still live, and opening a
     * call screen for a call that has already ended is worse than doing
     * nothing.
     */
    fun handleIntent(intent: Intent?) {
        if (intent?.action != OngoingCallService.ACTION_RETURN_TO_CALL) return
        OngoingCallBridge.notifyReturn(
            intent.getStringExtra(OngoingCallService.EXTRA_CALL_ID) ?: "",
        )
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start", "update" -> {
                val callId = call.argument<String>("callId") ?: ""
                val title = call.argument<String>("title") ?: "Voice call"
                val subtitle = call.argument<String>("subtitle") ?: "Ongoing call"
                val sharing = call.argument<Boolean>("screenSharing") ?: false
                val connected = call.argument<Boolean>("connected") ?: true
                // Epoch ms; a Dart int arrives as Integer or Long by size.
                val connectedAt = call.argument<Number>("connectedAt")?.toLong() ?: 0L
                val requestId = nextRequestId.incrementAndGet()
                OngoingCallBridge.awaitForeground(requestId, result)
                val queued = if (call.method == "start") {
                    OngoingCallService.start(
                        context, requestId, callId, title, subtitle, sharing, connected,
                        connectedAt,
                    )
                } else {
                    OngoingCallService.update(
                        context, requestId, callId, title, subtitle, sharing, connected,
                        connectedAt,
                    )
                }
                if (!queued) {
                    OngoingCallBridge.completeForeground(requestId, false)
                }
            }

            "stop" -> {
                OngoingCallService.stop(context)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "com.ababilx.app/ongoing_call"
        private const val EVENT_CHANNEL = "com.ababilx.app/ongoing_call/events"
        private val nextRequestId = AtomicLong()
    }
}

/**
 * The static seam between the service and whichever engine is currently
 * listening. Static because the service has no reference to the Activity, and
 * because a Hang up press can land in the gap between the Activity being
 * recreated and Dart re-subscribing — those events are held rather than lost.
 */
object OngoingCallBridge {

    private val main = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<Map<String, Any?>>()
    private var sink: EventChannel.EventSink? = null
    private val foregroundResults = mutableMapOf<Long, MethodChannel.Result>()

    /** Completes only after Service.startForeground itself succeeds or fails. */
    @Synchronized
    fun awaitForeground(requestId: Long, result: MethodChannel.Result) {
        foregroundResults[requestId] = result
        main.postDelayed({ completeForeground(requestId, false) }, FOREGROUND_TIMEOUT_MS)
    }

    @Synchronized
    fun completeForeground(requestId: Long, ready: Boolean) {
        val result = foregroundResults.remove(requestId) ?: return
        main.post { result.success(ready) }
    }

    @Synchronized
    fun attach(next: EventChannel.EventSink?) {
        sink = next
        if (next == null || pending.isEmpty()) return
        val drained = pending.toList()
        pending.clear()
        drained.forEach { event -> main.post { next.success(event) } }
    }

    fun notifyHangUp(callId: String) = emit("hang_up", callId)

    fun notifyReturn(callId: String) = emit("return_to_call", callId)

    /**
     * Not held for a later listener: a stale "stopped" delivered after the
     * user shared again would end the new share.
     */
    fun notifyScreenShareStopped() = emit("screen_share_stopped", "", hold = false)

    @Synchronized
    private fun emit(action: String, callId: String, hold: Boolean = true) {
        val event = mapOf("action" to action, "call_id" to callId)
        val target = sink
        if (target == null) {
            if (hold) pending.add(event)
            return
        }
        main.post { target.success(event) }
    }

    private const val FOREGROUND_TIMEOUT_MS = 5_000L
}
