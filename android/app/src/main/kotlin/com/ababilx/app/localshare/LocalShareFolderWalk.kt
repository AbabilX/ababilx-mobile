package com.ababilx.app.localshare

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import java.io.File
import java.util.UUID

/** One file of a picked folder, copied where the app can read it. */
data class WalkedFile(val path: String, val relPath: String, val mime: String) {
    fun toMap(): Map<String, String> =
        mapOf("path" to path, "relPath" to relPath, "mime" to mime)
}

/**
 * Walks a Storage Access Framework tree and copies every file into the app's
 * cache, remembering each one's path inside the folder.
 *
 * The tree URI is the only access the user granted, and it is not a path: the
 * files can live on an SD card, in another app's provider, or in the cloud.
 * Copying is therefore the only way Dart can stream them. Names come from the
 * provider and are used for the relative path only — every copy is written
 * under a random name, so nothing a provider reports can choose where it
 * lands.
 */
object LocalShareFolderWalk {
    private const val MAX_FILES = 5000
    private const val MAX_DEPTH = 32

    fun name(context: Context, tree: Uri): String {
        val root = DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        return runCatching {
            context.contentResolver.query(
                root,
                arrayOf(Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
        }.getOrNull()?.takeIf { it.isNotBlank() } ?: "Folder"
    }

    fun copy(context: Context, tree: Uri): List<WalkedFile> {
        val target = File(context.cacheDir, "local_share_out/${UUID.randomUUID()}")
        target.mkdirs()
        val out = ArrayList<WalkedFile>()
        walk(context, tree, DocumentsContract.getTreeDocumentId(tree), "", 0, target, out)
        return out
    }

    private fun walk(
        context: Context,
        tree: Uri,
        documentId: String,
        prefix: String,
        depth: Int,
        target: File,
        out: MutableList<WalkedFile>,
    ) {
        if (depth > MAX_DEPTH || out.size >= MAX_FILES) return
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
        val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
        )
        val rows = ArrayList<Triple<String, String, String>>()
        context.contentResolver.query(children, columns, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(1)?.takeIf(::safeSegment) ?: continue
                rows.add(Triple(cursor.getString(0), name, cursor.getString(2) ?: ""))
            }
        }
        for ((id, name, mime) in rows) {
            if (out.size >= MAX_FILES) return
            val rel = if (prefix.isEmpty()) name else "$prefix/$name"
            if (mime == Document.MIME_TYPE_DIR) {
                walk(context, tree, id, rel, depth + 1, target, out)
                continue
            }
            val copy = File(target, "${out.size}_${UUID.randomUUID()}")
            val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
            val copied = runCatching {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    copy.outputStream().use(input::copyTo)
                } != null
            }.getOrDefault(false)
            if (copied) {
                out.add(WalkedFile(copy.absolutePath, rel, mime.ifBlank { DEFAULT_MIME }))
            } else {
                copy.delete()
            }
        }
    }

    /** A name that is one path segment and nothing else. */
    private fun safeSegment(name: String): Boolean =
        name.isNotBlank() && name != "." && name != ".." &&
            !name.contains('/') && !name.contains('\\') &&
            name.none { it.code < 0x20 || it.code == 0x7F }

    private const val DEFAULT_MIME = "application/octet-stream"
}
