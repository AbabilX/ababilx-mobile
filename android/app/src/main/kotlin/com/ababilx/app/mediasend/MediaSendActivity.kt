package com.ababilx.app.mediasend

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.view.WindowCompat
import com.ababilx.app.R
import com.ababilx.app.mediasend.MediaSendRequest.Companion.START_CAMERA
import com.ababilx.app.mediasend.MediaSendRequest.Companion.START_FILES
import com.ababilx.app.mediasend.MediaSendRequest.Companion.START_REVIEW
import com.ababilx.app.mediasend.editor.EditorView
import com.ababilx.app.mediasend.gallery.GalleryView
import com.ababilx.app.mediasend.review.ReviewView
import java.util.concurrent.Executors

/**
 * The whole media-send flow, in one Activity: library grid → review → editor.
 *
 * One Activity rather than three because the three screens share a decoded
 * bitmap cache and a selection list; handing those between Activities is what
 * makes most Android picker flows feel like they reload.
 *
 * What the caller asked for is [MediaSendRequest]; which screen is up and
 * where Back goes is [MediaSendNavigator]; what has been picked and where each
 * piece came from is [MediaSendSelection]. This class is the wiring between
 * them and the pickers.
 */
class MediaSendActivity : Activity() {

    private lateinit var gallery: GalleryView
    private lateinit var review: ReviewView
    private lateinit var editor: EditorView
    private lateinit var loader: ThumbnailLoader
    private lateinit var pickers: MediaSendPickers
    private lateinit var nav: MediaSendNavigator
    private lateinit var request: MediaSendRequest

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val selection = MediaSendSelection()

    private var quality = MediaQuality.STANDARD
    private var galleryLoaded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Draw behind the status and navigation bars ourselves, on every
        // version — not just the API 35+ default — so MediaSendInsets is the
        // one thing responsible for keeping chrome clear of them.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContentView(R.layout.media_send_activity)
        request = MediaSendRequest.from(intent)
        quality = request.quality

        loader = ThumbnailLoader(this)
        gallery = findViewById(R.id.gallery_view)
        review = findViewById(R.id.review_view)
        editor = findViewById(R.id.editor_view)
        // The three screens marked their own bars while inflating above; this
        // is the single listener that feeds all of them.
        MediaSendInsets.install(findViewById(R.id.media_send_root))

        nav = MediaSendNavigator(
            gallery = gallery,
            review = review,
            editor = editor,
            startsAtGallery = request.startsAtGallery,
            onGalleryShown = ::loadGalleryOnce,
            onEditorClosed = ::closeEditor,
            cancel = ::cancel,
        )
        pickers = MediaSendPickers(
            activity = this,
            maxDocuments = request.maxSelection,
            onCaptured = ::onCaptured,
            onDocuments = ::onDocumentsPicked,
            onNothing = ::onPickerClosedEmpty,
        )

        wireGallery()
        wireReview()
        editor.onCancel = ::closeEditor
        editor.onDone = { nav.showReview(); review.refreshCurrent() }

        when (request.start) {
            START_CAMERA -> pickers.openCamera()
            START_FILES -> pickers.openFiles()
            START_REVIEW -> if (!openHandedItems()) cancel()
            else -> nav.showGallery()
        }
    }

    private fun wireGallery() {
        gallery.maxSelection = request.maxSelection
        gallery.allowVideo = request.allowVideo
        gallery.onClose = { nav.leaveGallery() }
        gallery.onCamera = { pickers.openCamera() }
        gallery.onFiles = { pickers.openFiles() }
        gallery.onNext = { entries ->
            toReview(selection.mergeGrid(entries.map(::pick), review.selection()))
        }
    }

    private fun wireReview() {
        review.attach(loader, PREVIEW_PX)
        review.quality = quality
        review.onBack = { nav.leaveReview() }
        review.onAddCamera = { pickers.openCamera() }
        review.onAddGallery = { nav.showGallery() }
        review.onAddFiles = { pickers.openFiles() }
        review.onEmptied = { nav.leaveReview() }
        review.onEditRequested = ::openEditor
        review.onSend = { items, caption, chosen ->
            quality = chosen
            finishWith(items + selection.passthrough, caption)
        }
    }

    /**
     * The grid reads MediaStore on [GalleryView.start], and that is deferred: a
     * flow opened at the camera may reach the grid for the first time through
     * "+ Add more". The flag is set only once the read actually begins, so a
     * refused permission does not leave the grid permanently blank.
     */
    private fun loadGalleryOnce() {
        if (galleryLoaded) return
        if (MediaSendPermissions.granted(this)) startGallery() else MediaSendPermissions.request(this)
    }

    private fun startGallery() {
        galleryLoaded = true
        gallery.start()
    }

    private fun onCaptured(item: PickedItem) {
        // A camera shot is not the grid's. Remembering it is what stops
        // "+ Add more" — which replaces the list with the grid's own — from
        // dropping the photo just taken.
        selection.remember(listOf(item))
        toReview(review.selection() + item)
    }

    /**
     * The caller already has the items — a share from another app. Anything
     * reviewable opens the review screen; the rest rides along untouched.
     *
     * @return false when there was nothing usable at all.
     */
    private fun openHandedItems(): Boolean {
        if (request.uris.isEmpty()) return false
        val items = selection.itemsFrom(this, request.uris, request.names, request.mimes)
        if (items.isEmpty()) return false
        onDocumentsPicked(items)
        return true
    }

    /**
     * Files can hand back a mix. Anything reviewable joins the review screen;
     * a document has nothing to review and is sent straight through.
     */
    private fun onDocumentsPicked(items: List<PickedItem>) {
        val media = selection.acceptDocuments(items)
        if (media.isNotEmpty()) {
            toReview(review.selection() + media)
            return
        }
        if (selection.passthrough.isNotEmpty()) {
            finishWith(selection.passthrough.toList(), "")
        }
    }

    /** A camera or document picker closed with nothing chosen. */
    private fun onPickerClosedEmpty() {
        if (review.selection().isNotEmpty()) {
            nav.showReview()
            return
        }
        if (selection.passthrough.isNotEmpty()) return
        if (request.startsAtGallery) nav.showGallery() else cancel()
    }

    private fun toReview(items: List<PickedItem>) {
        if (items.isEmpty()) return
        // Keep the edits already made to anything that is still selected.
        val existing = review.selection().associateBy { it.uri }
        for (item in items) existing[item.uri]?.let(item::copyEditsFrom)
        review.show(items)
        nav.showReview()
    }

    private fun openEditor(item: PickedItem) {
        loader.bitmap(item.uri, item.isVideo, PREVIEW_PX) { bitmap ->
            editor.open(bitmap, item)
            nav.showEditor()
        }
    }

    private fun closeEditor() {
        editor.revert()
        nav.showReview()
        review.refreshCurrent()
    }

    private fun pick(entry: GalleryEntry) = PickedItem(
        uri = entry.uri,
        name = entry.name,
        mime = entry.mime,
        isVideo = entry.isVideo,
        sizeBytes = entry.sizeBytes,
    )

    private fun finishWith(items: List<PickedItem>, caption: String) {
        io.execute {
            val exported = items.mapNotNull { MediaSendExport.export(this, it, quality) }
            main.post {
                if (exported.isEmpty()) {
                    cancel()
                    return@post
                }
                setResult(RESULT_OK, MediaSendResult.intent(exported, caption, quality.code))
                finish()
            }
        }
    }

    private fun cancel() {
        setResult(RESULT_CANCELED)
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() = nav.back()

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        pickers.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            // A library refusal is not a dead end: Files needs no permission of
            // ours, so the document picker is offered instead of an empty grid.
            MediaSendPermissions.REQUEST_CODE ->
                if (MediaSendPermissions.granted(this)) startGallery() else pickers.openFiles()

            // A camera refusal *is* one — there is no other way to take a
            // photo, and this flow was opened to take one.
            MediaSendPermissions.CAMERA_REQUEST_CODE ->
                if (MediaSendPermissions.cameraGranted(this)) {
                    pickers.openCamera()
                } else {
                    Toast.makeText(this, R.string.media_send_camera_denied, Toast.LENGTH_SHORT)
                        .show()
                    onPickerClosedEmpty()
                }
        }
    }

    override fun onDestroy() {
        io.shutdownNow()
        gallery.dispose()
        loader.dispose()
        super.onDestroy()
    }

    private companion object {
        const val PREVIEW_PX = 1600
    }
}
