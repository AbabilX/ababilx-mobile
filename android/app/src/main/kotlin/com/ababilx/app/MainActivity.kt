package com.ababilx.app

import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ababilx.app/ringtone",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startRingtone()
                    result.success(null)
                }
                "stop" -> {
                    stopRingtone()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startRingtone() {
        stopRingtone()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val tone = RingtoneManager.getRingtone(applicationContext, uri) ?: return
        tone.audioAttributes =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            tone.isLooping = true
        }
        tone.play()
        ringtone = tone
    }

    private fun stopRingtone() {
        try {
            ringtone?.stop()
        } catch (_: Exception) {
        }
        ringtone = null
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }
}
