package com.ababilx.app.backup

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.io.DataInputStream

/**
 * Reads the clear header of a backup file (Dart `BackupHeader`):
 * `"ABXBAK" 0x00 0x01 | u32 big-endian length | UTF-8 JSON`. Only the account
 * id is taken from it — enough to tell whose file this is without a key.
 */
object BackupHeader {
    private val MAGIC = byteArrayOf(0x41, 0x42, 0x58, 0x42, 0x41, 0x4B, 0x00, 0x01)
    private const val MAX_HEADER = 64 * 1024

    /** The `user_id` in [document]'s header, or null when it is not a backup. */
    fun owner(context: Context, document: Uri): String? = runCatching {
        context.contentResolver.openInputStream(document)?.use { raw ->
            val input = DataInputStream(raw.buffered())
            val magic = ByteArray(MAGIC.size)
            input.readFully(magic)
            if (!magic.contentEquals(MAGIC)) return@use null
            val length = input.readInt()
            if (length !in 1..MAX_HEADER) return@use null
            val json = ByteArray(length)
            input.readFully(json)
            JSONObject(String(json, Charsets.UTF_8)).optString("user_id").ifEmpty { null }
        }
    }.getOrNull()
}
