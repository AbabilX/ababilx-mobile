package com.ababilx.app

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ababilx.app/media_store",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val subfolder = call.argument<String>("subfolder") ?: ""
                    val mimeType = call.argument<String>("mimeType")
                    val collection = call.argument<String>("collection") ?: "downloads"
                    val deleteSource = call.argument<Boolean>("deleteSource") ?: true
                    if (sourcePath == null || fileName == null) {
                        result.error("bad_args", "sourcePath and fileName are required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val savedPath = MediaStoreBridge.saveToDownloads(
                            applicationContext,
                            sourcePath,
                            fileName,
                            subfolder,
                            mimeType,
                            collection,
                            deleteSource,
                        )
                        runOnUiThread {
                            if (savedPath != null) {
                                result.success(savedPath)
                            } else {
                                result.error("save_failed", "Could not save file to Downloads", null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startRingtone() {
        stopRingtone()
        val uri = ringtoneUri() ?: return
        try {
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(applicationContext, uri)
            player.isLooping = true
            player.prepare()
            player.start()
            mediaPlayer = player
        } catch (_: Exception) {
            stopRingtone()
        }
    }

    private fun ringtoneUri(): Uri? {
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        if (ringtone != null) return ringtone
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    private fun stopRingtone() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }
}
