package com.ababilx.app

import android.content.ContentValues
import android.content.Context
import net.zetetic.database.sqlcipher.SQLiteDatabase
import net.zetetic.database.sqlcipher.SQLiteOpenHelper

data class StoredChatMessage(
    val id: String,
    val conversationId: String,
    val createdAtMs: Long,
    val threadRootId: String?,
    val payloadJson: String,
    val payloadId: String,
)

/** Small encrypted database whose message id is the sole conflict key. */
class ChatMessageDatabase(context: Context) : SQLiteOpenHelper(
    context.applicationContext,
    DATABASE_NAME,
    ChatDatabaseSecret.get(context),
    null,
    DATABASE_VERSION,
    0,
    null,
    null,
    true,
) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE messages (
              id TEXT PRIMARY KEY NOT NULL,
              conversation_id TEXT NOT NULL,
              created_at_ms INTEGER NOT NULL,
              thread_root_id TEXT,
              payload_json TEXT NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX messages_timeline ON messages " +
                "(conversation_id, thread_root_id, created_at_ms, id)",
        )
        db.execSQL("CREATE TABLE migration_scopes (scope TEXT PRIMARY KEY NOT NULL)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun upsert(rows: List<StoredChatMessage>) {
        if (rows.isEmpty()) return
        val database = writableDatabase
        database.beginTransaction()
        try {
            rows.forEach { row ->
                val values = ContentValues().apply {
                    put("id", row.id)
                    put("conversation_id", row.conversationId)
                    put("created_at_ms", row.createdAtMs)
                    put("thread_root_id", row.threadRootId)
                    put("payload_json", row.payloadJson)
                }
                database.insertWithOnConflict(
                    "messages",
                    null,
                    values,
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
                if (row.payloadId.isNotEmpty()) {
                    database.execSQL(
                        "DELETE FROM messages WHERE json_extract(payload_json, '\$.id') = ? AND id != ?",
                        arrayOf(row.payloadId, row.id),
                    )
                }
            }
            rows.map(StoredChatMessage::conversationId).toSet().forEach { id ->
                prune(database, id)
            }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
    }

    fun isLegacyMigrated(scope: String): Boolean =
        readableDatabase.rawQuery(
            "SELECT 1 FROM migration_scopes WHERE scope = ? LIMIT 1",
            arrayOf(scope),
        ).use { it.moveToFirst() }

    fun migrateLegacy(scope: String, rows: List<StoredChatMessage>) {
        upsert(rows)
        writableDatabase.execSQL(
            "INSERT OR IGNORE INTO migration_scopes (scope) VALUES (?)",
            arrayOf(scope),
        )
    }

    fun page(
        conversationId: String,
        limit: Int,
        beforeMs: Long?,
        beforeId: String?,
        threadRootId: String?,
    ): List<String> {
        val where = mutableListOf("conversation_id = ?")
        val args = mutableListOf(conversationId)
        if (threadRootId == null) {
            where += "thread_root_id IS NULL"
        } else {
            where += "thread_root_id = ?"
            args += threadRootId
        }
        if (beforeMs != null) {
            if (beforeId == null) {
                where += "created_at_ms <= ?"
                args += beforeMs.toString()
            } else {
                where += "(created_at_ms < ? OR (created_at_ms = ? AND id < ?))"
                args += listOf(beforeMs.toString(), beforeMs.toString(), beforeId)
            }
        }
        val newestFirst = mutableListOf<String>()
        readableDatabase.query(
            "messages",
            arrayOf("payload_json"),
            where.joinToString(" AND "),
            args.toTypedArray(),
            null,
            null,
            "created_at_ms DESC, id DESC",
            limit.coerceIn(1, MAX_PAGE).toString(),
        ).use { cursor ->
            while (cursor.moveToNext()) newestFirst += cursor.getString(0)
        }
        return newestFirst.asReversed()
    }

    /**
     * Reads the archive in one ascending keyset cursor, across every
     * conversation and every thread.
     *
     * Separate from [page] on purpose. `page` answers "what does this screen
     * show next", so it filters `thread_root_id IS NULL` and reads newest
     * first — which makes it structurally unable to see a thread reply, and
     * therefore unable to back one up. This reads rows regardless of
     * thread_root_id, oldest first, so an exporter can stream the whole
     * history and resume from where it stopped.
     *
     * Ordering is (created_at_ms, id) so the cursor is total: two messages
     * with the same millisecond still have a stable successor.
     */
    fun exportPage(afterMs: Long?, afterId: String?, limit: Int): List<String> {
        val where = mutableListOf<String>()
        val args = mutableListOf<String>()
        if (afterMs != null) {
            if (afterId == null) {
                where += "created_at_ms > ?"
                args += afterMs.toString()
            } else {
                where += "(created_at_ms > ? OR (created_at_ms = ? AND id > ?))"
                args += listOf(afterMs.toString(), afterMs.toString(), afterId)
            }
        }
        val payloads = mutableListOf<String>()
        readableDatabase.query(
            "messages",
            arrayOf("payload_json"),
            where.joinToString(" AND ").ifEmpty { null },
            args.toTypedArray().takeIf { it.isNotEmpty() },
            null,
            null,
            "created_at_ms ASC, id ASC",
            limit.coerceIn(1, MAX_PAGE).toString(),
        ).use { cursor ->
            while (cursor.moveToNext()) payloads += cursor.getString(0)
        }
        return payloads
    }

    fun hasOlder(conversationId: String, beforeMs: Long, beforeId: String?): Boolean {
        val boundary = if (beforeId == null) {
            "created_at_ms < ?"
        } else {
            "(created_at_ms < ? OR (created_at_ms = ? AND id < ?))"
        }
        val args = if (beforeId == null) {
            arrayOf(conversationId, beforeMs.toString())
        } else {
            arrayOf(conversationId, beforeMs.toString(), beforeMs.toString(), beforeId)
        }
        return readableDatabase.rawQuery(
            "SELECT 1 FROM messages WHERE conversation_id = ? " +
                "AND thread_root_id IS NULL AND $boundary LIMIT 1",
            args,
        ).use { it.moveToFirst() }
    }

    fun remove(messageId: String) {
        writableDatabase.delete("messages", "id = ?", arrayOf(messageId))
        writableDatabase.delete(
            "messages",
            "json_extract(payload_json, '\$.id') = ?",
            arrayOf(messageId),
        )
    }

    fun unsent(): List<String> {
        val out = mutableListOf<String>()
        readableDatabase.rawQuery(
            "SELECT payload_json FROM messages WHERE json_extract(payload_json, '\$.send_status') IN ('sending', 'failed')",
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) out += cursor.getString(0)
        }
        return out
    }

    fun clearConversation(conversationId: String) {
        writableDatabase.delete("messages", "conversation_id = ?", arrayOf(conversationId))
    }

    fun clearAll() {
        writableDatabase.delete("messages", null, null)
    }

    /**
     * Trims a conversation to MAX_KEEP rows. This is a runaway backstop, not a
     * retention policy: the phone is the archive and keeps far more history
     * than the server, which holds six months (see CHAT_RETENTION.md). Only a
     * conversation past a couple of hundred thousand messages ever reaches it.
     */
    private fun prune(database: SQLiteDatabase, conversationId: String) {
        database.execSQL(
            "DELETE FROM messages WHERE conversation_id = ? AND id NOT IN " +
                "(SELECT id FROM messages WHERE conversation_id = ? " +
                "ORDER BY created_at_ms DESC, id DESC LIMIT ?)",
            arrayOf<Any>(conversationId, conversationId, MAX_KEEP),
        )
    }

    private companion object {
        const val DATABASE_NAME = "ababilx_messages.db"
        const val DATABASE_VERSION = 1

        /** Local retention backstop. The phone outlives the server's window. */
        const val MAX_KEEP = 200_000

        /** Upper bound on one page read, so a query cannot pull the archive. */
        const val MAX_PAGE = 2_000
    }
}
