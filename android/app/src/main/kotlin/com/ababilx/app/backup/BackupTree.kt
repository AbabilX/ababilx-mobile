package com.ababilx.app.backup

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract

/**
 * Walks a picked folder one level at a time. The automatic backup keeps an
 * account's files under `<account id>/` with its media in `media/`, so a
 * restore from a granted folder has to look below the root — which
 * [BackupFolder.list] never does.
 */
object BackupTree {
    /** The entries directly inside [parent] (a document id), or the root. */
    fun children(context: Context, tree: Uri, parent: String?): List<Map<String, Any?>> {
        val parentId = parent ?: DocumentsContract.getTreeDocumentId(tree)
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val out = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(
            uri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: continue
                val document = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                val dir = cursor.getString(4) == DocumentsContract.Document.MIME_TYPE_DIR
                out += mapOf(
                    "id" to id,
                    "uri" to document.toString(),
                    "name" to name,
                    "bytes" to if (cursor.isNull(2)) 0L else cursor.getLong(2),
                    "modifiedMs" to if (cursor.isNull(3)) 0L else cursor.getLong(3),
                    "dir" to dir,
                    // Only a backup's header names an owner; media files are
                    // checked when they are opened.
                    "owner" to if (!dir && name.endsWith(BackupFolder.EXTENSION)) {
                        BackupHeader.owner(context, document)
                    } else {
                        null
                    },
                )
            }
        }
        return out
    }
}
