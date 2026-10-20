package com.ababilx.app

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * A short buzz at the moments of a call the user should feel: it connected,
 * it was declined (by this phone or by the other side), the microphone went
 * off or on.
 *
 * Flutter's HapticFeedback goes through View.performHapticFeedback, whose
 * CLOCK_TICK / KEYBOARD_TAP are faint or silent on many phones, and it only
 * ran on Flutter buttons — never for an answer on the lock screen or a peer's
 * decline. The Vibrator answers on every surface, and the predefined effects
 * (API 29+) are tuned per device by its maker.
 */
class CallHapticsChannel(private val context: Context) {

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
            "buzz" -> {
                runCatching { buzz(call.argument<String>("kind") ?: "") }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun buzz(kind: String) {
        val vibrator = vibrator() ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            vibrator.vibrate(legacyTimings(kind), -1)
            return
        }
        vibrator.vibrate(effect(kind, vibrator))
    }

    private fun effect(kind: String, vibrator: Vibrator): VibrationEffect {
        if (kind == PEER_DECLINED) {
            // Two firm pulses: not a tap this phone made, so it reads as news.
            val timings = longArrayOf(0, 70, 90, 70)
            return if (vibrator.hasAmplitudeControl()) {
                VibrationEffect.createWaveform(timings, intArrayOf(0, 255, 0, 255), -1)
            } else {
                VibrationEffect.createWaveform(timings, -1)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return VibrationEffect.createPredefined(
                when (kind) {
                    CONNECTED -> VibrationEffect.EFFECT_HEAVY_CLICK
                    DECLINED -> VibrationEffect.EFFECT_DOUBLE_CLICK
                    else -> VibrationEffect.EFFECT_CLICK
                },
            )
        }
        return VibrationEffect.createWaveform(legacyTimings(kind), -1)
    }

    private fun legacyTimings(kind: String): LongArray = when (kind) {
        CONNECTED -> longArrayOf(0, 45)
        DECLINED -> longArrayOf(0, 30, 70, 30)
        PEER_DECLINED -> longArrayOf(0, 70, 90, 70)
        else -> longArrayOf(0, 25)
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private companion object {
        const val CHANNEL = "com.ababilx.app/call_haptics"
        const val CONNECTED = "connected"
        const val DECLINED = "declined"
        const val PEER_DECLINED = "peerDeclined"
    }
}
