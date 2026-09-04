package com.ababilx.app.mediasend

import android.content.Context
import android.net.Uri

/**
 * What has been picked, and — crucially — where each piece came from.
 *
 * The library grid owns its own selection and reports it whole, so a trip back
 * into it *replaces* the review screen's list. Anything that did not come from
 * the grid would be lost that way: the shot the camera just took, the files
 * handed in by a share. Those are remembered here and merged back in.
 *
 * [passthrough] is the other half: documents nothing can review (a PDF, an
 * archive). They never reach the review screen but are exported with the
 * album, so one trip through Files is still one send.
 */
class MediaSendSelection {

    val passthrough = mutableListOf<PickedItem>()

    private val external = mutableSetOf<Uri>()

    /** Marks items as *not* the grid's, so a return to the grid keeps them. */
    fun remember(items: List<PickedItem>) {
        external += items.map { it.uri }
    }

    /**
     * A fresh grid selection, plus whatever non-grid items are still on the
     * review screen. Reading the survivors off [reviewing] rather than off a
     * list of our own is what makes removal stick: an item the user deleted in
     * the review screen is simply not there to be carried back.
     */
    fun mergeGrid(
        fromGrid: List<PickedItem>,
        reviewing: List<PickedItem>,
    ): List<PickedItem> {
        val gridUris = fromGrid.mapTo(mutableSetOf()) { it.uri }
        val kept = reviewing.filter { it.uri in external && it.uri !in gridUris }
        return kept + fromGrid
    }

    /** Splits a document pick; returns only what the review screen can show. */
    fun acceptDocuments(items: List<PickedItem>): List<PickedItem> {
        val (media, others) = items.partition { it.isMedia }
        passthrough += others
        remember(media)
        return media
    }

    /**
     * Items a caller already holds — a share from another app. The mime is
     * asked of the resolver only when the caller did not say, since a share
     * usually knows better than a `content://` lookup does.
     */
    fun itemsFrom(
        context: Context,
        uris: List<String>,
        names: List<String>,
        mimes: List<String>,
    ): List<PickedItem> = uris.mapIndexedNotNull { index, raw ->
        val uri = runCatching { Uri.parse(raw) }.getOrNull() ?: return@mapIndexedNotNull null
        val mime = mimes.getOrNull(index)
            ?: context.contentResolver.getType(uri)
            ?: "application/octet-stream"
        PickedItem(
            uri = uri,
            name = names.getOrNull(index) ?: MediaSendExport.displayName(context, uri, "media"),
            mime = mime,
            isVideo = mime.startsWith("video/"),
            sizeBytes = 0,
        )
    }
}
