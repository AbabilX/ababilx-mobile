package com.ababilx.app.mediasend.gallery

import android.content.Context
import android.net.Uri
import com.ababilx.app.MediaGalleryQuery
import com.ababilx.app.mediasend.GalleryAlbum
import com.ababilx.app.mediasend.GalleryEntry

/**
 * The grid's pages, read straight off MediaStore.
 *
 * Reuses [MediaGalleryQuery] — the cursor the Dart sheet already used — so
 * there is exactly one definition of "the device's library, newest first" and
 * the native and Flutter pickers can never disagree about what is on the phone.
 */
object GalleryRepository {

    const val PAGE = 90

    /**
     * The device's albums, Camera first and "All media" second — the same
     * order and the same synthetic bucket the Dart folder gallery draws, so
     * the two pickers name the user's albums identically.
     */
    fun albums(context: Context, allowVideo: Boolean): List<GalleryAlbum> {
        val kind = if (allowVideo) "all" else "image"
        return MediaGalleryQuery.folders(context, kind).mapNotNull { row ->
            val bucketId = row["bucketId"] as? String ?: return@mapNotNull null
            GalleryAlbum(
                bucketId = bucketId,
                title = row["title"] as? String ?: "Folder",
                count = (row["count"] as? Number)?.toInt() ?: 0,
                thumbnailUri = (row["thumbnailUri"] as? String)?.let(Uri::parse),
            )
        }
    }

    fun page(
        context: Context,
        offset: Int,
        allowVideo: Boolean,
        bucketId: String?,
    ): List<GalleryEntry> {
        val kind = if (allowVideo) "all" else "image"
        return MediaGalleryQuery.page(context, offset, PAGE, kind, bucketId).mapNotNull { row ->
            val uri = row["uri"] as? String ?: return@mapNotNull null
            GalleryEntry(
                uri = Uri.parse(uri),
                name = row["name"] as? String ?: "media",
                mime = row["mime"] as? String ?: "image/jpeg",
                isVideo = row["isVideo"] as? Boolean ?: false,
                sizeBytes = (row["size"] as? Number)?.toLong() ?: 0L,
                durationMs = (row["durationMs"] as? Number)?.toLong() ?: 0L,
            )
        }
    }
}
