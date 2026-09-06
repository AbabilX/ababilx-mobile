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

    /** Switching album throws the old rows away rather than appending to them. */
    fun clear() {
        val had = entries.size
        entries.clear()
        if (had > 0) notifyItemRangeRemoved(0, had)
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

    /**
     * A selection change repaints the badge and nothing else.
     *
     * Tapping one photo can renumber every other one, so the whole grid is
     * told it changed — but a full bind would re-request the thumbnail of
     * every visible cell and re-install its click listener for a disc that
     * moved from "2" to "1". With the payload the tap costs a text change per
     * visible cell, which is what makes the number appear on the finger rather
     * than a beat behind it.
     */
    override fun onBindViewHolder(holder: Cell, position: Int, payloads: List<Any>) {
        if (payloads.contains(PAYLOAD_SELECTION)) {
            paintSelection(holder, entries[position])
            return
        }
        super.onBindViewHolder(holder, position, payloads)
    }

    override fun onBindViewHolder(holder: Cell, position: Int) {
        val entry = entries[position]
        loader.load(holder.image, entry.uri, entry.isVideo, cellSize)
        paintSelection(holder, entry)

        holder.duration.visibility = if (entry.isVideo) View.VISIBLE else View.GONE
        if (entry.isVideo) holder.duration.text = clock(entry.durationMs)

        holder.itemView.setOnClickListener { onTap(entry) }
    }

    private fun paintSelection(holder: Cell, entry: GalleryEntry) {
        val order = selection.indexOf(entry.uri)
        val picked = order >= 0
        holder.badge.text = if (picked) (order + 1).toString() else ""
        holder.badge.setBackgroundResource(
            if (picked) R.drawable.ms_selection_filled else R.drawable.ms_selection_ring,
        )
        holder.dim.visibility = if (picked) View.VISIBLE else View.GONE
    }

    private fun clock(ms: Long): String {
        val total = ms / 1000
        return "%d:%02d".format(total / 60, total % 60)
    }

    companion object {
        /** "The badge moved" — never "the photo changed". */
        const val PAYLOAD_SELECTION = "selection"
    }
}
