package com.ababilx.app.mediasend

import android.content.Context
import com.ababilx.app.mediasend.review.ReviewView

/**
 * Everything that can arrive with something picked, and where it goes.
 *
 * Four doors lead here — the grid's Next, a camera shot, the document picker,
 * and a share handed in from another app — and they differ only in what they
 * bring. Keeping the routing in one place is what stops each door growing its
 * own idea of when the review screen opens and when the flow just ends.
 */
class MediaSendIntake(
    private val context: Context,
    private val review: ReviewView,
    private val nav: MediaSendNavigator,
    private val selection: MediaSendSelection,
    private val request: MediaSendRequest,
    private val finish: (List<PickedItem>, String) -> Unit,
    private val cancel: () -> Unit,
) {

    fun pick(entry: GalleryEntry) = PickedItem(
        uri = entry.uri,
        name = entry.name,
        mime = entry.mime,
        isVideo = entry.isVideo,
        sizeBytes = entry.sizeBytes,
    )

    /**
     * A camera shot is not the grid's. Remembering it is what stops
     * "+ Add more" — which replaces the list with the grid's own — from
     * dropping the photo just taken.
     */
    fun captured(item: PickedItem) {
        selection.remember(listOf(item))
        toReview(review.selection() + item)
    }

    /**
     * The caller already has the items — a share from another app. Anything
     * reviewable opens the review screen; the rest rides along untouched.
     *
     * @return false when there was nothing usable at all.
     */
    fun openHandedItems(): Boolean {
        if (request.uris.isEmpty()) return false
        val items = selection.itemsFrom(context, request.uris, request.names, request.mimes)
        if (items.isEmpty()) return false
        review.setCaption(request.caption)
        documentsPicked(items)
        return true
    }

    /**
     * Files can hand back a mix. Anything reviewable joins the review screen;
     * a document has nothing to review and is sent straight through.
     */
    fun documentsPicked(items: List<PickedItem>) {
        val media = selection.acceptDocuments(items)
        if (media.isNotEmpty()) {
            toReview(review.selection() + media)
            return
        }
        if (selection.passthrough.isNotEmpty()) {
            finish(selection.passthrough.toList(), "")
        }
    }

    /** A camera or document picker closed with nothing chosen. */
    fun pickerClosedEmpty() {
        if (review.selection().isNotEmpty()) {
            nav.showReview()
            return
        }
        if (selection.passthrough.isNotEmpty()) return
        if (request.startsAtGallery) nav.showGallery() else cancel()
    }

    fun toReview(items: List<PickedItem>) {
        if (items.isEmpty()) return
        // Keep the edits already made to anything that is still selected.
        val existing = review.selection().associateBy { it.uri }
        for (item in items) existing[item.uri]?.let(item::copyEditsFrom)
        review.show(items)
        nav.showReview()
    }
}
