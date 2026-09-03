package com.ababilx.app.mediasend

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.core.view.WindowCompat
import com.ababilx.app.R
import com.ababilx.app.mediasend.editor.EditorView
import com.ababilx.app.mediasend.gallery.GalleryView
import com.ababilx.app.mediasend.review.ReviewView
import java.util.concurrent.Executors

/**
 * The whole media-send flow, in one Activity: library grid → review → editor.
 *
 * One Activity rather than three because the three screens share a decoded
 * bitmap cache and a selection list; handing those between Activities is what
 * makes most Android picker flows feel like they reload. Back walks the stack
 * (editor → review → gallery → cancel) exactly as Signal's does.
 */
class MediaSendActivity : Activity() {

    private lateinit var gallery: GalleryView
    private lateinit var review: ReviewView
    private lateinit var editor: EditorView
    private lateinit var loader: ThumbnailLoader

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var maxSelection = 10
    private lateinit var pickers: MediaSendPickers

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Draw behind the status and navigation bars ourselves, on every
        // version — not just the API 35+ default — so MediaSendInsets is the
        // one thing responsible for keeping chrome clear of them.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContentView(R.layout.media_send_activity)
        maxSelection = intent.getIntExtra(EXTRA_MAX, 10)
        pickers = MediaSendPickers(
            activity = this,
            maxDocuments = maxSelection,
            onCaptured = { item -> toReview(review.selection() + item) },
            onDocuments = { items -> finishWith(items, "") },
        )
        val allowVideo = intent.getBooleanExtra(EXTRA_ALLOW_VIDEO, true)

        loader = ThumbnailLoader(this)
        gallery = findViewById(R.id.gallery_view)
        review = findViewById(R.id.review_view)
        editor = findViewById(R.id.editor_view)
        // The three screens marked their own bars while inflating above; this
        // is the single listener that feeds all of them.
        MediaSendInsets.install(findViewById(R.id.media_send_root))

        gallery.maxSelection = maxSelection
        gallery.allowVideo = allowVideo
        gallery.onClose = { cancel() }
        gallery.onCamera = { pickers.openCamera() }
        gallery.onFiles = { pickers.openFiles() }
        gallery.onNext = { entries -> toReview(entries.map(::pick)) }

        review.attach(loader, PREVIEW_PX)
        review.onBack = { showOnly(gallery) }
        review.onAddMore = { showOnly(gallery) }
        review.onEmptied = { showOnly(gallery) }
        review.onEditRequested = { item -> openEditor(item) }
        review.onSend = { items, caption -> finishWith(items, caption) }

        editor.onCancel = {
            editor.revert()
            showOnly(review)
            review.refreshCurrent()
        }
        editor.onDone = {
            showOnly(review)
            review.refreshCurrent()
        }

        if (MediaSendPermissions.granted(this)) gallery.start() else MediaSendPermissions.request(this)
    }

    override fun onDestroy() {
        io.shutdownNow()
        gallery.dispose()
        loader.dispose()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        when {
            editor.visibility == View.VISIBLE -> {
                editor.revert()
                showOnly(review)
                review.refreshCurrent()
            }
            review.visibility == View.VISIBLE -> showOnly(gallery)
            else -> cancel()
        }
    }

    private fun pick(entry: GalleryEntry) = PickedItem(
        uri = entry.uri,
        name = entry.name,
        mime = entry.mime,
        isVideo = entry.isVideo,
        sizeBytes = entry.sizeBytes,
    )

    private fun toReview(items: List<PickedItem>) {
        if (items.isEmpty()) return
        // Keep the edits already made to anything that is still selected.
        val existing = review.selection().associateBy { it.uri }
        for (item in items) existing[item.uri]?.let(item::copyEditsFrom)
        review.show(items)
        showOnly(review)
    }

    private fun openEditor(item: PickedItem) {
        loader.bitmap(item.uri, item.isVideo, PREVIEW_PX) { bitmap ->
            editor.open(bitmap, item)
            showOnly(editor)
        }
    }

    private fun showOnly(target: View) {
        gallery.visibility = if (target === gallery) View.VISIBLE else View.GONE
        review.visibility = if (target === review) View.VISIBLE else View.GONE
        editor.visibility = if (target === editor) View.VISIBLE else View.GONE
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        pickers.onActivityResult(requestCode, resultCode, data)
    }

    private fun finishWith(items: List<PickedItem>, caption: String) {
        io.execute {
            val exported = items.mapNotNull { MediaSendExport.export(this, it) }
            main.post {
                if (exported.isEmpty()) {
                    cancel()
                    return@post
                }
                setResult(RESULT_OK, MediaSendResult.intent(exported, caption))
                finish()
            }
        }
    }

    private fun cancel() {
        setResult(RESULT_CANCELED)
        finish()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MediaSendPermissions.REQUEST_CODE) return
        // A refusal is not a dead end: Files needs no permission of ours, so
        // the document picker is offered instead of an empty grid.
        if (MediaSendPermissions.granted(this)) gallery.start() else pickers.openFiles()
    }

    companion object {
        const val EXTRA_MAX = "max_selection"
        const val EXTRA_ALLOW_VIDEO = "allow_video"

        private const val PREVIEW_PX = 1600
    }
}
