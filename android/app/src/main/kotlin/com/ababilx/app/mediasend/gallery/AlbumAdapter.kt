package com.ababilx.app.mediasend.gallery

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.ababilx.app.R
import com.ababilx.app.mediasend.GalleryAlbum
import com.ababilx.app.mediasend.ThumbnailLoader

/**
 * The album list the Gallery button opens on: a cover, a name and a count.
 *
 * Covers go through the same [ThumbnailLoader] the grid uses, so opening an
 * album a second time costs nothing — its cover is already the first cell's
 * bitmap, at the same size, under the same cache key.
 */
class AlbumAdapter(
    private val loader: ThumbnailLoader,
    private val coverSize: Int,
    private val onOpen: (GalleryAlbum) -> Unit,
) : RecyclerView.Adapter<AlbumAdapter.Row>() {

    private val albums = mutableListOf<GalleryAlbum>()

    fun submit(next: List<GalleryAlbum>) {
        albums.clear()
        albums.addAll(next)
        notifyDataSetChanged()
    }

    val count: Int get() = albums.size

    class Row(view: View) : RecyclerView.ViewHolder(view) {
        val cover: ImageView = view.findViewById(R.id.album_cover)
        val title: TextView = view.findViewById(R.id.album_title)
        val subtitle: TextView = view.findViewById(R.id.album_count)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Row {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.media_send_album_row, parent, false)
        return Row(view)
    }

    override fun getItemCount() = albums.size

    override fun onBindViewHolder(holder: Row, position: Int) {
        val album = albums[position]
        holder.title.text = album.title
        holder.subtitle.text = album.count.toString()
        val cover = album.thumbnailUri
        if (cover == null) {
            holder.cover.setImageDrawable(null)
        } else {
            loader.load(holder.cover, cover, false, coverSize)
        }
        holder.itemView.setOnClickListener { onOpen(album) }
    }
}
