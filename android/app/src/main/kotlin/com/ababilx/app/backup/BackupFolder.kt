package com.ababilx.app.backup

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import java.io.File

/**
 * The folder the person picked for local backups, through the Storage Access
 * Framework — Signal-Android's model. A picked folder outlives a reinstall on
 * disk; only the permission to it does not, which is why a restore on a new
 * install starts by picking the folder again.
 *
 * Only ciphertext ever arrives here: Dart seals the file in the app's cache
 * and this copies it across. Nothing in this file reads a byte of content.
 */
object BackupFolder {
    /**
     * The provider would not create our file here. On Android 11+ that is
     * usually a media folder: Recordings, Music, Ringtones and the like take
     * audio only, Pictures and DCIM images and video, so MediaProvider refuses
     * an `.abxbackup` inside them however the folder was picked.
     */
    class FolderRefusedException(cause: Throwable?) : Exception("folder refused a new file", cause)

    const val EXTENSION = ".abxbackup"
    private const val PARTIAL = ".partial"
    private const val MIME = "application/octet-stream"

    /**
     * [owner] is the account id from the file's clear header, never guessed
     * from the name: the name carries the username, which can change or be
     * empty, and a folder can hold several people's backups.
     */
    data class Entry(
        val uri: Uri,
        val name: String,
        val bytes: Long,
        val modifiedMs: Long,
        val owner: String?,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "uri" to uri.toString(),
            "name" to name,
            "bytes" to bytes,
            "modifiedMs" to modifiedMs,
            "owner" to owner,
        )
    }

    fun hasAccess(context: Context, tree: Uri): Boolean =
        context.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission && it.isWritePermission
        }

    fun label(context: Context, tree: Uri): String? = runCatching {
        val root = rootDocument(tree)
        context.contentResolver.query(
            root,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }
    }.getOrNull()

    /** Every backup in the folder, newest first, whichever account wrote it. */
    fun list(context: Context, tree: Uri): List<Entry> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val out = mutableListOf<Entry>()
        context.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(1) ?: continue
                if (!name.endsWith(EXTENSION) && !name.endsWith(EXTENSION + PARTIAL)) continue
                val uri = DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                out += Entry(
                    uri,
                    name,
                    if (cursor.isNull(2)) 0L else cursor.getLong(2),
                    if (cursor.isNull(3)) 0L else cursor.getLong(3),
                    BackupHeader.owner(context, uri),
                )
            }
        }
        return out.sortedByDescending { it.modifiedMs }
    }

    /**
     * Copies [source] in as [name], then keeps only the newest [keep] backups
     * whose header names [owner] — this account's. Another account's files in
     * the same folder are never touched, whatever they are called.
     *
     * Written as `name.partial` and renamed when complete, so a copy cut short
     * (the phone died, the folder vanished) can never be taken for a backup,
     * and pruning never counts it. The old files are removed only after the new
     * one is whole — a failed run costs nothing that was already there.
     */
    fun write(context: Context, tree: Uri, source: File, name: String, owner: String, keep: Int): Entry {
        val resolver = context.contentResolver
        val root = rootDocument(tree)
        list(context, tree)
            .filter { it.owner == owner && it.name.endsWith(PARTIAL) }
            .forEach { runCatching { DocumentsContract.deleteDocument(resolver, it.uri) } }

        val partial = create(resolver, root, name + PARTIAL)
        try {
            copy(context, source, partial)
        } catch (error: Throwable) {
            runCatching { DocumentsContract.deleteDocument(resolver, partial) }
            throw error
        }
        val final = runCatching { DocumentsContract.renameDocument(resolver, partial, name) }.getOrNull()
            ?: run {
                // Some providers cannot rename. Write the final name directly and
                // drop the partial; the file is small next to losing a backup.
                val direct = create(resolver, root, name)
                copy(context, source, direct)
                runCatching { DocumentsContract.deleteDocument(resolver, partial) }
                direct
            }

        list(context, tree)
            .filter { it.owner == owner && it.name.endsWith(EXTENSION) }
            .sortedByDescending { it.modifiedMs }
            .drop(keep)
            .forEach { runCatching { DocumentsContract.deleteDocument(resolver, it.uri) } }
        return Entry(final, name, source.length(), System.currentTimeMillis(), owner)
    }

    /** Copies a picked backup into the app's cache so Dart can read it. */
    fun copyToCache(context: Context, document: Uri, dest: File): Long {
        dest.parentFile?.mkdirs()
        val input = context.contentResolver.openInputStream(document)
            ?: error("backup file cannot be opened")
        return input.use { stream -> dest.outputStream().use { stream.copyTo(it, 1 shl 16) } }
    }

    fun describe(context: Context, document: Uri): Map<String, Any?> {
        var name: String? = null
        var bytes = 0L
        context.contentResolver.query(document, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameAt = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeAt = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameAt >= 0) name = cursor.getString(nameAt)
                if (sizeAt >= 0 && !cursor.isNull(sizeAt)) bytes = cursor.getLong(sizeAt)
            }
        }
        return mapOf("uri" to document.toString(), "name" to name, "bytes" to bytes)
    }

    /**
     * Whether a backup can actually be written here: creates, writes and
     * deletes a probe named like a real backup. Asked right after the folder is
     * picked, so a media folder is refused with a reason on the spot instead
     * of failing every night.
     */
    fun canWrite(context: Context, tree: Uri): Boolean {
        val resolver = context.contentResolver
        val probe = runCatching { create(resolver, rootDocument(tree), "AbabilX-check$EXTENSION$PARTIAL") }
            .getOrNull() ?: return false
        return try {
            resolver.openOutputStream(probe, "w").use { requireNotNull(it).write(0) }
            true
        } catch (_: Exception) {
            false
        } finally {
            runCatching { DocumentsContract.deleteDocument(resolver, probe) }
        }
    }

    private fun create(resolver: android.content.ContentResolver, root: Uri, name: String): Uri =
        try {
            DocumentsContract.createDocument(resolver, root, MIME, name)
        } catch (error: Exception) {
            throw FolderRefusedException(error)
        } ?: throw FolderRefusedException(null)

    private fun rootDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun copy(context: Context, source: File, target: Uri) {
        context.contentResolver.openOutputStream(target, "w").use { output ->
            requireNotNull(output) { "folder refused the write" }
            source.inputStream().use { it.copyTo(output, 1 shl 16) }
        }
    }
}
