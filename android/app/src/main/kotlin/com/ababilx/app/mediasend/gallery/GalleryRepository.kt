package com.ababilx.app.mediasend.gallery

import android.content.Context
import android.net.Uri
import com.ababilx.app.MediaGalleryQuery
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

    fun page(context: Context, offset: Int, allowVideo: Boolean): List<GalleryEntry> {
        val kind = if (allowVideo) "all" else "image"
        return MediaGalleryQuery.page(context, offset, PAGE, kind).mapNotNull { row ->
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
