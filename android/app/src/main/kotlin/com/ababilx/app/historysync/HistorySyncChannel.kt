package com.ababilx.app.historysync

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `com.ababilx.app/history_sync`: Dart brackets an open live history link
 * with `started` / `ended`, which run [HistorySyncService].
 */
class HistorySyncChannel(private val context: Context) {
    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "started" -> {
                        HistorySyncService.start(context, call.argument<String>("device").orEmpty())
                        result.success(null)
                    }
                    "ended" -> {
                        HistorySyncService.stop(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val CHANNEL = "com.ababilx.app/history_sync"
    }
}
