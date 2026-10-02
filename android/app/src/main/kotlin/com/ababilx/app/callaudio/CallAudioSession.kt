package com.ababilx.app.callaudio

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's handle on the call's [CallAudioManager] — the commands Signal sends
 * as `AudioManagerCommand`s, and the device list back as `devices` events.
 *
 * One manager per call, process-wide: the ringback ([com.ababilx.app.CallRingback])
 * can start it before Dart's engine does, as Signal initializes audio and
 * starts the outgoing ringer in one step; whoever comes second joins it.
 */
object CallAudioSession {

    private const val CHANNEL = "com.ababilx.app/call_audio"

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var manager: CallAudioManager? = null
    private var callId: String? = null

    val running: Boolean get() = manager != null

    /** The device the call's audio is on now, or null with no call running. */
    val activeDevice: CallAudioDevice? get() = manager?.snapshot?.active

    /** Told on the main thread whenever the call's device changes. */
    private val routeWatchers = mutableSetOf<() -> Unit>()

    fun watchRoute(watcher: () -> Unit) {
        routeWatchers += watcher
    }

    fun unwatchRoute(watcher: () -> Unit) {
        routeWatchers -= watcher
    }

    private fun routeChanged() {
        routeWatchers.toList().forEach { it() }
    }

    fun attach(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result -> handle(app, call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val defaultSpeaker = call.argument<Boolean>("defaultSpeaker") ?: false
                val user = CallAudioDevice.fromWire(call.argument<String>("userDevice"))
                start(context, call.argument<String>("callId"), defaultSpeaker, user)
                result.success(null)
            }
            "setDefault" -> {
                val device = if (call.argument<Boolean>("speaker") == true) {
                    CallAudioDevice.SPEAKER_PHONE
                } else {
                    CallAudioDevice.EARPIECE
                }
                val clear = call.argument<Boolean>("clearEarpiece") ?: false
                manager?.let { m -> m.post { m.setDefaultAudioDevice(device, clear) } }
                result.success(null)
            }
            "select" -> {
                val id = call.argument<Int>("id")
                manager?.let { m -> if (id != null) m.post { m.selectAudioDevice(id) } }
                result.success(null)
            }
            "selectType" -> {
                val device = CallAudioDevice.fromWire(call.argument<String>("type"))
                manager?.let { m -> if (device != null) m.post { m.selectAudioDevice(device) } }
                result.success(null)
            }
            "snapshot" -> result.success(manager?.snapshot?.toMap())
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Starts the call's audio, or joins the one already running for [id].
     * A different call's manager is stopped first: one call owns the audio.
     */
    fun start(
        context: Context,
        id: String?,
        defaultSpeaker: Boolean,
        user: CallAudioDevice? = null,
    ) {
        val current = manager
        if (current != null && (id == null || callId == null || id == callId)) {
            if (callId == null) callId = id
            apply(current, defaultSpeaker, user)
            return
        }
        current?.shutdown()
        callId = id
        val created = CallAudioManager.create(context.applicationContext, id) { snapshot ->
            main.post {
                channel?.invokeMethod("devices", snapshot.toMap())
                routeChanged()
            }
        }
        Log.i(CallAudioManager.TAG, "session ${created.javaClass.simpleName} for $id")
        manager = created
        created.post { created.start() }
        apply(created, defaultSpeaker, user)
    }

    /**
     * The ringback's entry: starts the call's audio if nothing has yet, on the
     * speaker when that was chosen, and otherwise leaves the running call's
     * choices alone.
     */
    fun ensureStarted(context: Context, speaker: Boolean) {
        if (manager != null) return
        start(context, null, defaultSpeaker = false, user = if (speaker) CallAudioDevice.SPEAKER_PHONE else null)
    }

    private fun apply(manager: CallAudioManager, defaultSpeaker: Boolean, user: CallAudioDevice?) {
        val device = if (defaultSpeaker) CallAudioDevice.SPEAKER_PHONE else CallAudioDevice.EARPIECE
        manager.post {
            manager.setDefaultAudioDevice(device, false)
            if (user != null) manager.selectAudioDevice(user)
        }
    }

    fun stop() {
        val current = manager ?: return
        Log.i(CallAudioManager.TAG, "session stop for $callId")
        manager = null
        callId = null
        current.shutdown()
        main.post {
            channel?.invokeMethod("devices", null)
            routeChanged()
        }
    }
}
