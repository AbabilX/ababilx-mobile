package com.ababilx.app.mediasend.gallery

import android.net.Uri
import com.ababilx.app.mediasend.GalleryEntry

/**
 * What has been picked in the grid, in the order it was tapped.
 *
 * Tap order is the send order, which is why this is two parallel lists rather
 * than a set: [uris] is handed to [GalleryAdapter] by reference so a cell can
 * read its own badge number straight off it without a copy per bind.
 *
 * Selection survives moving between albums — the same photo stays numbered
 * when you come back to it — because nothing here is cleared by a bucket
 * change; only the grid's rows are.
 */
class GalleryChoices(private val max: Int) {

    private val entries = mutableListOf<GalleryEntry>()

    /** Live view of the picked URIs, in tap order. Do not copy this. */
    val uris = mutableListOf<Uri>()

    val size: Int get() = entries.size

    val isEmpty: Boolean get() = entries.isEmpty()

    fun snapshot(): List<GalleryEntry> = entries.toList()

    /** @return false when the cap was hit, so the caller can say so. */
    fun toggle(entry: GalleryEntry): Boolean {
        val index = uris.indexOf(entry.uri)
        if (index >= 0) {
            uris.removeAt(index)
            entries.removeAt(index)
            return true
        }
        if (entries.size >= max) return false
        uris.add(entry.uri)
        entries.add(entry)
        return true
    }
}
