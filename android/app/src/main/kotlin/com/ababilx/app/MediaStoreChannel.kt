package com.ababilx.app

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `com.ababilx.app/media_store`: copies a file into Downloads or the gallery
 * when the user presses Save — never on its own. Moved out of MainActivity
 * unchanged; the work is [MediaStoreBridge].
 */
class MediaStoreChannel(private val activity: Activity) {
    fun attach(engine: FlutterEngine) {
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
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
                            activity.applicationContext,
                            sourcePath,
                            fileName,
                            subfolder,
                            mimeType,
                            collection,
                            deleteSource,
                        )
                        activity.runOnUiThread {
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
}
