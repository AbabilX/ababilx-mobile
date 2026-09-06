package com.ababilx.app.mediasend

import android.view.View
import com.ababilx.app.mediasend.editor.EditorView
import com.ababilx.app.mediasend.gallery.GalleryView
import com.ababilx.app.mediasend.review.ReviewView

/**
 * Which of the three screens is up, and where Back goes from each.
 *
 * The screens are siblings in one layout rather than a real back stack, so
 * this is the back stack — every route between them goes through here.
 *
 * [onGalleryShown] fires each time the grid is revealed, because the grid
 * loads MediaStore lazily and a flow opened at the camera may reach it for the
 * first time through "+ Add more". The Activity keeps the once-only guard;
 * showing the grid without telling it to load is what produced an empty black
 * screen after "+".
 */
class MediaSendNavigator(
    private val gallery: GalleryView,
    private val review: ReviewView,
    private val editor: EditorView,
    private val startsAtGallery: Boolean,
    private val onGalleryShown: () -> Unit,
    private val onEditorClosed: () -> Unit,
    private val cancel: () -> Unit,
) {

    fun showGallery() {
        show(gallery)
        onGalleryShown()
    }

    fun showReview() = show(review)

    fun showEditor() = show(editor)

    val reviewVisible: Boolean get() = review.visibility == View.VISIBLE
    val editorVisible: Boolean get() = editor.visibility == View.VISIBLE
    val galleryVisible: Boolean get() = gallery.visibility == View.VISIBLE

    /**
     * Leaving the review screen. Opened at the grid there is a screen behind
     * it; opened at the camera, at Files or over handed items there is not, so
     * backing out of the review screen backs out of the whole flow.
     */
    fun leaveReview() {
        if (startsAtGallery) showGallery() else cancel()
    }

    /** Closing the grid must not throw away pictures already under review. */
    fun leaveGallery() {
        if (review.selection().isEmpty()) cancel() else showReview()
    }

    fun back() {
        when {
            editorVisible -> onEditorClosed()
            review.dismissSheet() -> Unit
            reviewVisible -> leaveReview()
            // Inside an album, Back is "up to the album list" — the picker is
            // two screens deep now, and leaving the flow from the first Back
            // would throw away a selection made inside an album.
            galleryVisible && gallery.backToAlbums() -> Unit
            galleryVisible && review.selection().isNotEmpty() -> showReview()
            else -> cancel()
        }
    }

    private fun show(target: View) {
        gallery.visibility = if (target === gallery) View.VISIBLE else View.GONE
        review.visibility = if (target === review) View.VISIBLE else View.GONE
        editor.visibility = if (target === editor) View.VISIBLE else View.GONE
    }
}
