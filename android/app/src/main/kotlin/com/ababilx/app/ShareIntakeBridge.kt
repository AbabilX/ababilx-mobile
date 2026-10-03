package com.ababilx.app

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.core.content.pm.ShortcutManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Reads what another app handed us through the system share sheet.
 *
 * Signal's shape, and for its reason: the incoming `content://` URIs are held
 * as-is and read through [ContentResolver] only when the user actually sends.
 * Nothing is copied on arrival — sharing a 2 GB video and then changing your
 * mind must not cost 2 GB of cache.
 *
 * The read grant rides on the Activity that received the intent
 * (FLAG_GRANT_READ_URI_PERMISSION) and lasts as long as its task, which is the
 * whole life of a share. If the process dies, the share dies with it — the
 * user simply shares again.
 */
object ShareIntakeBridge {

    /**
     * Describes one shared item without touching its bytes: name, type and
     * size all come from the resolver's metadata row.
     */
    private fun describe(resolver: ContentResolver, uri: Uri): JSONObject? {
        var name = ""
        var size = -1L
        try {
            resolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        name = cursor.getString(nameIndex) ?: ""
                    }
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        size = cursor.getLong(sizeIndex)
                    }
                }
            }
        } catch (_: Exception) {
            // A provider that refuses to be queried can still be readable;
            // fall through to the last path segment for a name.
        }
        if (name.isBlank()) name = uri.lastPathSegment?.substringAfterLast('/') ?: ""
        if (name.isBlank()) name = "shared-file"

        val mime = try {
            resolver.getType(uri) ?: ""
        } catch (_: Exception) {
            ""
        }

        return JSONObject().apply {
            put("uri", uri.toString())
            put("name", name)
            put("mimeType", mime)
            put("size", size)
        }
    }

    /**
     * Turns an incoming intent into the share payload, or null when the intent
     * is not a share (a launcher tap, a notification, a call).
     */
    fun parse(context: Context, intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action == DirectShareShortcuts.ACTION_OPEN) {
            // A Direct Share shortcut tapped from the launcher's long press.
            val id = intent.getStringExtra(DirectShareShortcuts.EXTRA_CONVERSATION_ID)
            if (!DirectShareShortcuts.isConversationId(id)) return null
            return JSONObject().put("open_conversation", id).toString()
        }
        if (intent.action == UserLinkIntent.ACTION_OPEN) {
            // A personal message link, tapped in a browser or another chat.
            val handle = UserLinkIntent.forwardedHandle(
                intent.getStringExtra(UserLinkIntent.EXTRA_HANDLE),
            ) ?: return null
            return JSONObject().put("open_user", handle).toString()
        }
        val uris = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(streamExtra(intent))
            Intent.ACTION_SEND_MULTIPLE -> streamListExtra(intent)
            else -> return null
        }
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim().orEmpty()

        val files = JSONArray()
        val resolver = context.contentResolver
        for (uri in uris) {
            describe(resolver, uri)?.let(files::put)
        }
        if (files.length() == 0 && text.isEmpty()) return null

        return JSONObject().apply {
            put("text", text)
            put("files", files)
            // Picked from a Direct Share target: the chat is already chosen.
            put(
                "target_conversation_id",
                DirectShareShortcuts.conversationIdOf(
                    intent.getStringExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID),
                ) ?: "",
            )
        }.toString()
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java).orEmpty()
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        }

    /**
     * Copies one shared item into our cache and returns its path. Called only
     * for files the user chose to send, and only once per send.
     */
    fun materialize(context: Context, uriString: String, fileName: String): String? {
        val uri = Uri.parse(uriString)
        val dir = File(context.cacheDir, "shared").apply { mkdirs() }
        // The sender's display name is not unique and not trusted; keep it for
        // the extension only and let a UUID own the path.
        val safeName = fileName.substringAfterLast('/').ifBlank { "shared-file" }
        val target = File(dir, "${UUID.randomUUID()}-$safeName")
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use(input::copyTo)
            } ?: return null
            if (target.length() <= 0L) null else target.absolutePath
        } catch (_: Exception) {
            target.delete()
            null
        }
    }
}
