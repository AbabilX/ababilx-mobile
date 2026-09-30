package com.ababilx.app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Dart decides which chats are share targets (it holds the list, the locks and
 * the signed-in state); [DirectShareShortcuts] does everything else. Both
 * calls return at once — the work runs on the shortcuts' own worker.
 */
class DirectShareChannel(private val context: Context) {

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publish" -> {
                        val raw = call.argument<List<Map<String, Any?>>>("targets").orEmpty()
                        val hidden = call.argument<List<String>>("hidden").orEmpty()
                            .filter(DirectShareShortcuts::isConversationId)
                        DirectShareShortcuts.publishAsync(
                            context,
                            raw.mapNotNull(::target),
                            hidden,
                        )
                        result.success(null)
                    }
                    "reportUsed" -> {
                        val ids = call.argument<List<String>>("ids").orEmpty()
                        DirectShareShortcuts.reportUsedAsync(context, ids)
                        result.success(null)
                    }
                    "clear" -> {
                        DirectShareShortcuts.clearAsync(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun target(map: Map<String, Any?>): DirectShareShortcuts.Target? {
        val id = map["id"] as? String ?: return null
        if (!DirectShareShortcuts.isConversationId(id)) return null
        return DirectShareShortcuts.Target(
            conversationId = id,
            name = map["name"] as? String ?: "",
            avatarUrl = map["avatarUrl"] as? String ?: "",
            isGroup = map["isGroup"] as? Boolean ?: false,
        )
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/direct_share"
    }
}
