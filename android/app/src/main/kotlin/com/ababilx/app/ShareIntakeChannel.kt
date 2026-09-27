package com.ababilx.app

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridges [ShareIntakeBridge] to Dart.
 *
 * Two doors on purpose. A share that cold-starts the app is already sitting on
 * the Activity's intent before Dart exists, so Dart pulls it with
 * `getInitialShare`; a share that arrives while the app is running comes
 * through `onNewIntent` and is pushed over the event channel. Miss either one
 * and the share silently vanishes in exactly one of the two cases, which is
 * the classic way this feature ships half-broken.
 */
class ShareIntakeChannel(private val activity: Activity) {

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null

    /** The cold-start share, held until Dart asks for it exactly once. */
    private var pending: String? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(::onMethod)
        // Direct Share targets are the other half of the share sheet.
        DirectShareChannel(activity.applicationContext).attach(engine)

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            })
    }

    /** Call from `onCreate` (via the launch intent) and from `onNewIntent`. */
    fun handleIntent(intent: Intent?, initial: Boolean) {
        val payload = ShareIntakeBridge.parse(activity, intent) ?: return
        if (initial) {
            pending = payload
            return
        }
        // Running already: hand it straight over. If Dart has not attached its
        // listener yet, hold it as the initial share instead of dropping it.
        val sink = events
        if (sink == null) {
            pending = payload
        } else {
            main.post { sink.success(payload) }
        }
    }

    fun dispose() {
        events = null
        io.shutdown()
    }

    private fun onMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInitialShare" -> {
                result.success(pending)
                pending = null
            }
            "clear" -> {
                pending = null
                result.success(null)
            }
            "materialize" -> {
                val uri = call.argument<String>("uri")
                val name = call.argument<String>("name") ?: "shared-file"
                if (uri == null) {
                    result.error("bad_args", "uri is required", null)
                    return
                }
                offload(result) { ShareIntakeBridge.materialize(activity, uri, name) }
            }
            "thumbnail" -> {
                val uri = call.argument<String>("uri")
                val maxPx = call.argument<Int>("maxPx") ?: 256
                if (uri == null) {
                    result.error("bad_args", "uri is required", null)
                    return
                }
                offload(result) { ShareThumbnails.of(activity, uri, maxPx) }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Reads and decodes run off the main thread — a shared video can be
     * hundreds of megabytes, and copying it on the UI thread would freeze the
     * picker mid-scroll.
     */
    private fun offload(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try {
                work()
            } catch (e: Exception) {
                main.post { result.error("share_failed", e.message, null) }
                return@execute
            }
            main.post { result.success(value) }
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "com.ababilx.app/share_intake"
        const val EVENT_CHANNEL = "com.ababilx.app/share_intake/events"
    }
}
