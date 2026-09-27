package com.ababilx.app

import android.content.ContentValues
import net.zetetic.database.sqlcipher.SQLiteDatabase

/**
 * The text of messages that came back from a local backup, one row per
 * message id, beside `messages` in the same SQLCipher database.
 *
 * A restore after "start fresh" brings back ciphertext no key opens any more.
 * The message row stays exactly as the server has it, so a later server page
 * overwrites nothing that matters; the readable text lives here instead, and
 * the phone asks here only once its own key has failed. Values arrive already
 * sealed by Dart under a key derived from the account backup key, so this
 * table holds no readable body even inside the encrypted database — the rule
 * the `messages` table follows (an encrypted message's body is stored empty).
 */
object RestoredBodies {
    private const val TABLE = "restored_bodies"

    fun create(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS $TABLE (" +
                "message_id TEXT PRIMARY KEY NOT NULL, sealed TEXT NOT NULL)",
        )
    }

    fun putAll(db: SQLiteDatabase, rows: Map<String, String>) {
        if (rows.isEmpty()) return
        db.beginTransaction()
        try {
            rows.forEach { (id, sealed) ->
                if (id.isEmpty() || sealed.isEmpty()) return@forEach
                db.insertWithOnConflict(
                    TABLE,
                    null,
                    ContentValues().apply {
                        put("message_id", id)
                        put("sealed", sealed)
                    },
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun get(db: SQLiteDatabase, messageId: String): String? =
        db.rawQuery(
            "SELECT sealed FROM $TABLE WHERE message_id = ?",
            arrayOf(messageId),
        ).use { if (it.moveToFirst()) it.getString(0) else null }

    /** A deleted message takes its restored text with it. */
    fun remove(db: SQLiteDatabase, messageId: String) {
        db.delete(TABLE, "message_id = ?", arrayOf(messageId))
    }

    /** Rows whose message is gone from `messages` (a cleared conversation). */
    fun removeOrphans(db: SQLiteDatabase) {
        db.execSQL(
            "DELETE FROM $TABLE WHERE message_id NOT IN " +
                "(SELECT json_extract(payload_json, '\$.id') FROM messages " +
                "WHERE json_extract(payload_json, '\$.id') IS NOT NULL)",
        )
    }

    fun clear(db: SQLiteDatabase) {
        db.delete(TABLE, null, null)
    }
}
