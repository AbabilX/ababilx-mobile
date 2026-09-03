package com.ababilx.app.mediasend.gallery

import android.net.Uri
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.ababilx.app.R
import com.ababilx.app.mediasend.GalleryEntry
import com.ababilx.app.mediasend.ThumbnailLoader

/**
 * The library grid. Selection is shown the way Signal shows it: a numbered
 * disc, so the order the photos were tapped in is the order they are sent in.
 */
class GalleryAdapter(
    private val loader: ThumbnailLoader,
    private val cellSize: Int,
    private val selection: List<Uri>,
    private val onTap: (GalleryEntry) -> Unit,
) : RecyclerView.Adapter<GalleryAdapter.Cell>() {

    private val entries = mutableListOf<GalleryEntry>()

    fun append(more: List<GalleryEntry>) {
        if (more.isEmpty()) return
        val start = entries.size
        entries.addAll(more)
        notifyItemRangeInserted(start, more.size)
    }

    val count: Int get() = entries.size

    class Cell(view: View) : RecyclerView.ViewHolder(view) {
        val image: ImageView = view.findViewById(R.id.cell_image)
        val dim: View = view.findViewById(R.id.cell_dim)
        val badge: TextView = view.findViewById(R.id.cell_badge)
        val duration: TextView = view.findViewById(R.id.cell_duration)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Cell {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.media_send_gallery_cell, parent, false)
        view.layoutParams = view.layoutParams.apply { height = cellSize }
        return Cell(view)
    }

    override fun getItemCount() = entries.size

    override fun onBindViewHolder(holder: Cell, position: Int) {
        val entry = entries[position]
        loader.load(holder.image, entry.uri, entry.isVideo, cellSize)

        val order = selection.indexOf(entry.uri)
        val picked = order >= 0
        holder.badge.text = if (picked) (order + 1).toString() else ""
        holder.badge.setBackgroundResource(
            if (picked) R.drawable.ms_selection_filled else R.drawable.ms_selection_ring,
        )
        holder.dim.visibility = if (picked) View.VISIBLE else View.GONE

        holder.duration.visibility = if (entry.isVideo) View.VISIBLE else View.GONE
        if (entry.isVideo) holder.duration.text = clock(entry.durationMs)

        holder.itemView.setOnClickListener { onTap(entry) }
    }

    private fun clock(ms: Long): String {
        val total = ms / 1000
        return "%d:%02d".format(total / 60, total % 60)
    }
}
