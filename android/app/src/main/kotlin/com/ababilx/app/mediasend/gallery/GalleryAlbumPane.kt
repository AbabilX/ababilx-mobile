package com.ababilx.app.mediasend.gallery

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.ababilx.app.MediaGalleryQuery
import com.ababilx.app.R
import com.ababilx.app.mediasend.GalleryAlbum
import com.ababilx.app.mediasend.ThumbnailLoader
import java.util.concurrent.Executors

/**
 * The album list, and the top-bar title that toggles back to it.
 *
 * Owns the folder read so [GalleryView] stays the wiring between the two
 * screens rather than the reader of both. The title is the only affordance:
 * inside an album it says the album's name and is tappable, on the list it
 * says "Albums" and is not.
 */
class GalleryAlbumPane(
    private val context: Context,
    private val list: RecyclerView,
    private val title: TextView,
    private val allowVideo: Boolean,
    private val onOpen: (GalleryAlbum) -> Unit,
) {

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var adapter: AlbumAdapter

    val visible: Boolean get() = list.visibility == View.VISIBLE

    /** Reads the albums and shows them, or falls straight into All media. */
    fun start(loader: ThumbnailLoader) {
        adapter = AlbumAdapter(loader, COVER_PX, onOpen)
        list.layoutManager = LinearLayoutManager(context)
        list.adapter = adapter
        list.setHasFixedSize(true)
        io.execute {
            val albums = GalleryRepository.albums(context, allowVideo)
            main.post {
                adapter.submit(albums)
                // No albums at all means nothing readable; the empty grid says
                // that better than an empty list, which reads as a failed load.
                if (albums.isEmpty()) onOpen(allMedia()) else show()
            }
        }
    }

    fun show() {
        title.text = context.getString(R.string.media_send_albums)
        title.isClickable = false
        list.visibility = View.VISIBLE
    }

    fun hide(albumTitle: String) {
        title.text = context.getString(R.string.media_send_album_title, albumTitle)
        title.isClickable = true
        list.visibility = View.GONE
    }

    fun dispose() = io.shutdownNow()

    private fun allMedia() = GalleryAlbum(
        bucketId = MediaGalleryQuery.ALL_MEDIA_BUCKET_ID,
        title = context.getString(R.string.media_send_all_media),
        count = 0,
        thumbnailUri = null,
    )

    private companion object {
        const val COVER_PX = 192
    }
}
