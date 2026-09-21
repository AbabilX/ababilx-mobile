package com.ababilx.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Runs every SQLCipher operation away from Flutter's platform thread.
 *
 * Writes are serialized on one thread; reads get their own. The database is
 * opened in WAL mode, so a read sees the last committed state while a write is
 * in progress — and opening a chat no longer waits behind a history restore's
 * queue of upserts, which is what made a restored DM look like it was still
 * fetching.
 */
class ChatMessageStoreChannel(context: android.content.Context) {
    private val database = ChatMessageDatabase(context)
    private val worker = Executors.newSingleThreadExecutor()
    private val reader = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "com.ababilx.app/chat_store",
        ).also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                when (call.method) {
                    "upsert" -> background(result) {
                        database.upsert(parseRows(call.argument<List<*>>("rows")))
                        null
                    }
                    "isLegacyMigrated" -> background(result, reader) {
                        database.isLegacyMigrated(
                            requiredString(call.argument("scope")),
                        )
                    }
                    "migrateLegacy" -> background(result) {
                        database.migrateLegacy(
                            requiredString(call.argument("scope")),
                            parseRows(call.argument<List<*>>("rows")),
                        )
                        null
                    }
                    "page" -> background(result, reader) {
                        database.page(
                            requiredString(call.argument("conversationId")),
                            (call.argument<Int>("limit") ?: 50),
                            call.argument<Number>("beforeMs")?.toLong(),
                            call.argument("beforeId"),
                            call.argument("threadRootId"),
                        )
                    }
                    "exportPage" -> background(result, reader) {
                        database.exportPage(
                            call.argument<Number>("afterMs")?.toLong(),
                            call.argument("afterId"),
                            (call.argument<Int>("limit") ?: 500),
                        )
                    }
                    "hasOlder" -> background(result, reader) {
                        database.hasOlder(
                            requiredString(call.argument("conversationId")),
                            requiredNumber(call.argument("beforeMs")).toLong(),
                            call.argument("beforeId"),
                        )
                    }
                    "remove" -> background(result) {
                        database.remove(requiredString(call.argument("messageId")))
                        null
                    }
                    "unsent" -> background(result, reader) {
                        database.unsent()
                    }
                    "clearConversation" -> background(result) {
                        database.clearConversation(
                            requiredString(call.argument("conversationId")),
                        )
                        null
                    }
                    "clearAll" -> background(result) {
                        database.clearAll()
                        null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        reader.shutdown()
        worker.execute(database::close)
        worker.shutdown()
    }

    private fun parseRows(rawRows: List<*>?): List<StoredChatMessage> =
        rawRows.orEmpty().mapNotNull { raw ->
            val row = raw as? Map<*, *> ?: return@mapNotNull null
            val id = row["id"] as? String ?: return@mapNotNull null
            val conversationId = row["conversationId"] as? String ?: return@mapNotNull null
            val createdAtMs = (row["createdAtMs"] as? Number)?.toLong() ?: return@mapNotNull null
            val payload = row["payloadJson"] as? String ?: return@mapNotNull null
            StoredChatMessage(
                id = id,
                conversationId = conversationId,
                createdAtMs = createdAtMs,
                threadRootId = row["threadRootId"] as? String,
                payloadJson = payload,
                recoverySource = row["recoverySource"] as? String,
                payloadId = (row["payloadId"] as? String)?.ifEmpty { id } ?: id,
            )
        }

    private fun <T> background(
        result: MethodChannel.Result,
        executor: java.util.concurrent.Executor = worker,
        operation: () -> T,
    ) {
        executor.execute {
            try {
                val value = operation()
                main.post { result.success(value) }
            } catch (error: Throwable) {
                // Never expose message data, SQL, or key material across the bridge.
                main.post {
                    result.error(
                        "chat_store_failed",
                        error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }
    }

    private fun requiredString(value: String?): String =
        requireNotNull(value).also { require(it.isNotEmpty()) }

    private fun requiredNumber(value: Number?): Number = requireNotNull(value)
}
