package com.ababilx.app.mediasend.gallery

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.SimpleItemAnimator
import com.ababilx.app.R
import com.ababilx.app.mediasend.GalleryAlbum
import com.ababilx.app.mediasend.GalleryEntry
import com.ababilx.app.mediasend.MediaSendInsets
import com.ababilx.app.mediasend.ThumbnailLoader

/**
 * The picker half of the flow: your albums, then one album as a grid, with
 * Camera and Files as escapes and a Next button that appears only once
 * something is chosen.
 *
 * **It opens on the album list, and that is the point.** The composer's "+"
 * panel already shows a rail of your most recent media, so a Gallery button
 * that opened on a full-screen copy of that rail was offering the same photos
 * twice and no route to the rest of the library. Albums first matches what
 * "Gallery" means everywhere else in this app (`showMediaFolderGallery`, used
 * by the profile picture and the wallpaper), and "All media" is the second row
 * so the old newest-first grid is still one tap away.
 */
class GalleryView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : LinearLayout(context, attrs) {

    var onClose: (() -> Unit)? = null
    var onCamera: (() -> Unit)? = null
    var onFiles: (() -> Unit)? = null
    var onNext: ((List<GalleryEntry>) -> Unit)? = null
    var maxSelection: Int = 10
    var allowVideo: Boolean = true

    private val grid: RecyclerView
    private val albumList: RecyclerView
    private val footer: FrameLayout
    private val counter: TextView
    private val empty: TextView
    private val title: TextView
    private lateinit var adapter: GalleryAdapter
    private lateinit var albums: GalleryAlbumPane
    private lateinit var paging: GalleryPaging
    private var loader: ThumbnailLoader? = null

    private var choices = GalleryChoices(maxSelection)
    init {
        orientation = VERTICAL
        LayoutInflater.from(context).inflate(R.layout.media_send_gallery, this, true)
        grid = findViewById(R.id.gallery_grid)
        albumList = findViewById(R.id.gallery_albums)
        footer = findViewById(R.id.gallery_footer)
        counter = findViewById(R.id.gallery_count)
        empty = findViewById(R.id.gallery_empty)
        title = findViewById(R.id.gallery_title)

        findViewById<ImageButton>(R.id.gallery_close).setOnClickListener { onClose?.invoke() }
        findViewById<ImageButton>(R.id.gallery_camera).setOnClickListener { onCamera?.invoke() }
        findViewById<ImageButton>(R.id.gallery_files).setOnClickListener { onFiles?.invoke() }
        findViewById<ImageButton>(R.id.gallery_next).setOnClickListener {
            if (!choices.isEmpty) onNext?.invoke(choices.snapshot())
        }
        // The album name doubles as the way back to the album list.
        title.setOnClickListener { backToAlbums() }

        MediaSendInsets.padTop(findViewById(R.id.gallery_topbar))
        MediaSendInsets.padBottom(footer)
    }

    /**
     * Called once the hosting Activity knows the library is readable.
     *
     * [shared] is the Activity's own cache, so a photo decoded for a grid cell
     * is not decoded again for the review screen's rail.
     */
    fun start(shared: ThumbnailLoader) {
        if (loader != null) return
        loader = shared
        val cell = resources.displayMetrics.widthPixels / COLUMNS
        choices = GalleryChoices(maxSelection)
        adapter = GalleryAdapter(shared, cell, choices.uris, ::toggle)
        albums = GalleryAlbumPane(context, albumList, title, allowVideo, ::openAlbum)
        paging = GalleryPaging(context, adapter, allowVideo, ::onGridChanged)

        grid.layoutManager = GridLayoutManager(context, COLUMNS)
        grid.adapter = adapter
        grid.setHasFixedSize(true)
        // A tap renumbers badges across the whole grid, and the default
        // animator answers that by cross-fading a second copy of every visible
        // cell. Turning it off is most of what made selection feel slow.
        (grid.itemAnimator as? SimpleItemAnimator)?.supportsChangeAnimations = false
        grid.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrolled(view: RecyclerView, dx: Int, dy: Int) {
                val manager = view.layoutManager as GridLayoutManager
                if (manager.findLastVisibleItemPosition() >= adapter.count - COLUMNS * 3) {
                    paging.more()
                }
            }
        })
        // The album list is the front door, so the grid starts hidden and is
        // revealed by openAlbum. Leaving it visible showed one frame of an
        // empty grid before the folder read landed.
        grid.visibility = View.GONE
        albums.start(shared)
    }

    fun dispose() {
        if (loader != null) {
            paging.dispose()
            albums.dispose()
        }
    }

    private fun openAlbum(album: GalleryAlbum) {
        albums.hide(album.title)
        grid.visibility = View.VISIBLE
        paging.open(album.bucketId)
    }

    private fun onGridChanged(count: Int) {
        if (albums.visible) return
        val nothing = count == 0
        empty.visibility = if (nothing) View.VISIBLE else View.GONE
        grid.visibility = if (nothing) View.GONE else View.VISIBLE
    }

    /**
     * Back inside the picker: one album's grid returns to the album list
     * rather than closing the whole flow, which is what Back means everywhere
     * a list drills into a screen.
     */
    fun backToAlbums(): Boolean {
        if (loader == null || albums.visible) return false
        albums.show()
        grid.visibility = View.GONE
        empty.visibility = View.GONE
        return true
    }

    private fun toggle(entry: GalleryEntry) {
        if (!choices.toggle(entry)) {
            Toast.makeText(
                context,
                resources.getString(R.string.media_send_limit, maxSelection),
                Toast.LENGTH_SHORT,
            ).show()
            return
        }
        // Removing from the middle of the selection renumbers every badge
        // after it, so the whole grid is told — but with a payload, so each
        // visible cell repaints its disc and keeps its thumbnail.
        adapter.notifyItemRangeChanged(0, adapter.count, GalleryAdapter.PAYLOAD_SELECTION)
        footer.visibility = if (choices.isEmpty) View.GONE else View.VISIBLE
        counter.text = resources.getQuantityString(
            R.plurals.media_send_selected,
            choices.size,
            choices.size,
        )
    }

    private companion object {
        const val COLUMNS = 3
    }
}
