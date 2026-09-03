package com.ababilx.app.mediasend.gallery

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
import com.ababilx.app.R
import com.ababilx.app.mediasend.GalleryEntry
import com.ababilx.app.mediasend.MediaSendInsets
import com.ababilx.app.mediasend.ThumbnailLoader
import java.util.concurrent.Executors

/**
 * The picker half of the flow: the device library as a grid, with Camera and
 * Files as escapes and a Next button that appears only once something is
 * chosen. Signal's attachment keyboard, full screen.
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
    private val footer: FrameLayout
    private val counter: TextView
    private val empty: TextView
    private lateinit var adapter: GalleryAdapter
    private lateinit var loader: ThumbnailLoader

    private val chosen = mutableListOf<GalleryEntry>()
    private val chosenUris = mutableListOf<Uri>()
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var loading = false
    private var exhausted = false

    init {
        orientation = VERTICAL
        LayoutInflater.from(context).inflate(R.layout.media_send_gallery, this, true)
        grid = findViewById(R.id.gallery_grid)
        footer = findViewById(R.id.gallery_footer)
        counter = findViewById(R.id.gallery_count)
        empty = findViewById(R.id.gallery_empty)

        findViewById<ImageButton>(R.id.gallery_close).setOnClickListener { onClose?.invoke() }
        findViewById<ImageButton>(R.id.gallery_camera).setOnClickListener { onCamera?.invoke() }
        findViewById<ImageButton>(R.id.gallery_files).setOnClickListener { onFiles?.invoke() }
        findViewById<ImageButton>(R.id.gallery_next).setOnClickListener {
            if (chosen.isNotEmpty()) onNext?.invoke(chosen.toList())
        }

        MediaSendInsets.padTop(findViewById(R.id.gallery_topbar))
        MediaSendInsets.padBottom(footer)
    }

    /** Called once the hosting Activity knows the library is readable. */
    fun start() {
        if (::adapter.isInitialized) return
        val columns = COLUMNS
        val cell = resources.displayMetrics.widthPixels / columns
        loader = ThumbnailLoader(context)
        adapter = GalleryAdapter(loader, cell, chosenUris, ::toggle)
        grid.layoutManager = GridLayoutManager(context, columns)
        grid.adapter = adapter
        grid.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrolled(view: RecyclerView, dx: Int, dy: Int) {
                val manager = view.layoutManager as GridLayoutManager
                if (manager.findLastVisibleItemPosition() >= adapter.count - columns * 3) {
                    loadMore()
                }
            }
        })
        loadMore()
    }

    fun dispose() {
        io.shutdownNow()
        if (::loader.isInitialized) loader.dispose()
    }

    private fun loadMore() {
        if (loading || exhausted) return
        loading = true
        val offset = adapter.count
        io.execute {
            val page = GalleryRepository.page(context, offset, allowVideo)
            main.post {
                loading = false
                if (page.size < GalleryRepository.PAGE) exhausted = true
                adapter.append(page)
                val nothing = adapter.count == 0
                empty.visibility = if (nothing) View.VISIBLE else View.GONE
                grid.visibility = if (nothing) View.GONE else View.VISIBLE
            }
        }
    }

    private fun toggle(entry: GalleryEntry) {
        val index = chosenUris.indexOf(entry.uri)
        if (index >= 0) {
            chosenUris.removeAt(index)
            chosen.removeAt(index)
        } else {
            if (chosen.size >= maxSelection) {
                Toast.makeText(
                    context,
                    resources.getString(R.string.media_send_limit, maxSelection),
                    Toast.LENGTH_SHORT,
                ).show()
                return
            }
            chosenUris.add(entry.uri)
            chosen.add(entry)
        }
        // Every visible badge can shift when one item leaves the middle of the
        // selection, so the whole grid is rebound rather than one cell.
        adapter.notifyItemRangeChanged(0, adapter.count)
        footer.visibility = if (chosen.isEmpty()) View.GONE else View.VISIBLE
        counter.text = resources.getQuantityString(
            R.plurals.media_send_selected,
            chosen.size,
            chosen.size,
        )
    }

    private companion object {
        const val COLUMNS = 3
    }
}
