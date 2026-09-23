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
 * piece came from is [MediaSendSelection]; what arrives picked and where it
 * goes is [MediaSendIntake]; every callback between the screens is
 * [MediaSendWiring], which also owns the chosen [MediaQuality].
 *
 * What is left here is the Activity's own job and nothing else: create the
 * views, hold the permission dance, receive the picker results, export, and
 * finish.
 */
class MediaSendActivity : Activity() {

    private lateinit var gallery: GalleryView
    private lateinit var review: ReviewView
    private lateinit var editor: EditorView
    private lateinit var loader: ThumbnailLoader
    private lateinit var pickers: MediaSendPickers
    private lateinit var nav: MediaSendNavigator
    private lateinit var intake: MediaSendIntake
    private lateinit var wiring: MediaSendWiring
    private lateinit var request: MediaSendRequest

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val selection = MediaSendSelection()

    private var galleryLoaded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Draw behind the status and navigation bars ourselves, on every
        // version — not just the API 35+ default — so MediaSendInsets is the
        // one thing responsible for keeping chrome clear of them. androidx
        // also makes both bars transparent with no contrast scrim, which the
        // theme used to do with attributes Android 15 deprecated.
        WindowCompat.enableEdgeToEdge(window)
        setContentView(R.layout.media_send_activity)
        request = MediaSendRequest.from(intent)

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
            onEditorClosed = { wiring.closeEditor() },
            cancel = ::cancel,
        )
        intake = MediaSendIntake(
            context = this,
            review = review,
            nav = nav,
            selection = selection,
            request = request,
            finish = ::finishWith,
            cancel = ::cancel,
        )
        pickers = MediaSendPickers(
            activity = this,
            maxDocuments = request.maxSelection,
            onCaptured = intake::captured,
            onDocuments = intake::documentsPicked,
            onNothing = intake::pickerClosedEmpty,
        )

        wiring = MediaSendWiring(
            gallery = gallery,
            review = review,
            editor = editor,
            nav = nav,
            pickers = pickers,
            intake = intake,
            selection = selection,
            loader = loader,
            request = request,
            previewPx = MediaSendPreview.sizeFor(resources),
            finish = ::finishWith,
        )
        wiring.install()

        when (request.start) {
            START_CAMERA -> pickers.openCamera()
            START_FILES -> pickers.openFiles()
            START_REVIEW -> if (!intake.openHandedItems()) cancel()
            else -> nav.showGallery()
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
        // One cache for all four screens: a cell decoded in the grid is the
        // same bitmap the album cover and the review rail ask for.
        gallery.start(loader)
    }

    private fun finishWith(items: List<PickedItem>, caption: String) {
        io.execute {
            val exported = MediaSendExport.exportAll(this, items, wiring.quality)
            main.post {
                if (exported.isEmpty()) {
                    cancel()
                    return@post
                }
                setResult(RESULT_OK, MediaSendResult.intent(exported, caption, wiring.quality.code))
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
                    intake.pickerClosedEmpty()
                }
        }
    }

    override fun onDestroy() {
        io.shutdownNow()
        gallery.dispose()
        loader.dispose()
        super.onDestroy()
    }
}
