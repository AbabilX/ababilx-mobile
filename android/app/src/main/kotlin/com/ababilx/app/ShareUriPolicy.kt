package com.ababilx.app

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import java.io.File

/**
 * Which URIs share intake may read.
 *
 * [ContentResolver] opens a URI with THIS app's permissions, so a URI another
 * app hands us must never point back into our own storage: a `file://` path,
 * or a `content://` authority answered by one of our own providers (ours and
 * every plugin's are non-exported, but non-exported only stops OTHER apps).
 * Both are refused where the intent arrives. The one own-storage source that
 * is legitimate is the review screen's export folder, which only the copy and
 * thumbnail paths accept.
 */
object ShareUriPolicy {
    /** Where [com.ababilx.app.mediasend.MediaSendExport] writes reviewed files. */
    private const val REVIEW_DIR = "mediasend"

    /** A URI another app sent: `content://` from a provider that is not ours. */
    fun acceptIncoming(context: Context, uri: Uri): Boolean {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
        val authority = uri.authority ?: return false
        return authority.split(';').none { isOwnAuthority(context, it) }
    }

    /** What may be copied or previewed: an incoming URI, or a reviewed file. */
    fun acceptForRead(context: Context, uri: Uri): Boolean = when (uri.scheme) {
        ContentResolver.SCHEME_CONTENT -> acceptIncoming(context, uri)
        ContentResolver.SCHEME_FILE -> isReviewedFile(context, uri)
        else -> false
    }

    private fun isOwnAuthority(context: Context, raw: String): Boolean {
        // "10@authority" addresses another Android user's copy of a provider.
        val authority = raw.substringAfterLast('@').trim()
        if (authority.isEmpty()) return true
        val own = context.packageName
        if (authority == own || authority.startsWith("$own.")) return true
        val owner = try {
            context.packageManager.resolveContentProvider(authority, 0)?.packageName
        } catch (_: Exception) {
            null
        }
        return owner == own
    }

    private fun isReviewedFile(context: Context, uri: Uri): Boolean {
        val path = uri.path ?: return false
        return try {
            val dir = File(context.cacheDir, REVIEW_DIR).canonicalFile
            File(path).canonicalFile.path.startsWith(dir.path + File.separator)
        } catch (_: Exception) {
            false
        }
    }
}
