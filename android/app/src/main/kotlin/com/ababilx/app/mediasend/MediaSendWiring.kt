package com.ababilx.app.mediasend

import com.ababilx.app.mediasend.editor.EditorView
import com.ababilx.app.mediasend.gallery.GalleryView
import com.ababilx.app.mediasend.review.ReviewView

/**
 * Every callback between the three screens, in one place.
 *
 * The Activity is left holding the lifecycle — permissions, the picker
 * results, the export, the finish — and this holds the wiring, which is the
 * part that grows every time a screen gains a button.
 *
 * It also owns [quality], because the review sheet is the only thing that can
 * change it and the export is the only thing that reads it. Two owners is how
 * the sheet and Settings → Media quality would come to disagree.
 */
class MediaSendWiring(
    private val gallery: GalleryView,
    private val review: ReviewView,
    private val editor: EditorView,
    private val nav: MediaSendNavigator,
    private val pickers: MediaSendPickers,
    private val intake: MediaSendIntake,
    private val selection: MediaSendSelection,
    private val loader: ThumbnailLoader,
    private val request: MediaSendRequest,
    private val previewPx: Int,
    private val finish: (List<PickedItem>, String) -> Unit,
) {

    var quality: MediaQuality = request.quality
        private set

    fun install() {
        wireGallery()
        wireReview()
        editor.onCancel = ::closeEditor
        editor.onDone = {
            nav.showReview()
            review.refreshCurrent()
        }
    }

    private fun wireGallery() {
        gallery.maxSelection = request.maxSelection
        gallery.allowVideo = request.allowVideo
        gallery.onClose = { nav.leaveGallery() }
        gallery.onCamera = { pickers.openCamera() }
        gallery.onFiles = { pickers.openFiles() }
        gallery.onNext = { entries ->
            intake.toReview(
                selection.mergeGrid(entries.map(intake::pick), review.selection()),
            )
        }
    }

    private fun wireReview() {
        review.attach(loader, previewPx)
        review.quality = quality
        review.viewOnce.allowed = request.allowViewOnce
        review.onBack = { nav.leaveReview() }
        review.onAddCamera = { pickers.openCamera() }
        review.onAddGallery = { nav.showGallery() }
        review.onAddFiles = { pickers.openFiles() }
        review.onEmptied = { nav.leaveReview() }
        review.onEditRequested = ::openEditor
        review.onSend = { items, caption, chosen ->
            quality = chosen
            finish(items + selection.passthrough, caption)
        }
    }

    private fun openEditor(item: PickedItem) {
        loader.bitmap(item.uri, item.isVideo, previewPx) { bitmap ->
            editor.open(bitmap, item)
            nav.showEditor()
        }
    }

    fun closeEditor() {
        editor.revert()
        nav.showReview()
        review.refreshCurrent()
    }
}
