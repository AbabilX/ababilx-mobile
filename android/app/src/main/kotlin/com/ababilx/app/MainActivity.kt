package com.ababilx.app

import com.ababilx.call_ringer.CallRinger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    override fun onDestroy() {
        // The in-app call screen died with the Activity; CallKit's own hold is
        // untouched, so a call ringing natively keeps ringing.
        CallRinger.release(FLUTTER_HOLDER)
        super.onDestroy()
    }

    companion object {
        /** Ring holder for the in-app call screen — mirrors `ring_holders.dart`. */
        private const val FLUTTER_HOLDER = "flutter"
    }
}
