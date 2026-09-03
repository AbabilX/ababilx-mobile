package com.ababilx.app.mediasend.review

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import androidx.recyclerview.widget.RecyclerView
import com.ababilx.app.R
import com.ababilx.app.mediasend.PickedItem
import com.ababilx.app.mediasend.ThumbnailLoader
import com.ababilx.app.mediasend.editor.EditableImageView

/**
 * The strip under the review pager: every picked item, plus a trailing `+`
 * that goes back to the library. Tapping a thumbnail jumps the pager to it.
 */
class RailAdapter(
    private val items: List<PickedItem>,
    private val loader: ThumbnailLoader,
    private val onSelect: (Int) -> Unit,
    private val onAddMore: () -> Unit,
) : RecyclerView.Adapter<RailAdapter.Cell>() {

    var selected: Int = 0
        set(value) {
            val previous = field
            field = value
            notifyItemChanged(previous)
            notifyItemChanged(value)
        }

    class Cell(view: View) : RecyclerView.ViewHolder(view) {
        val image: EditableImageView = view.findViewById(R.id.rail_image)
        val add: ImageView = view.findViewById(R.id.rail_add)
        val ring: View = view.findViewById(R.id.rail_selection)
    }

    override fun getItemCount() = items.size + 1

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Cell = Cell(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.media_send_rail_cell, parent, false),
    )

    override fun onBindViewHolder(holder: Cell, position: Int) {
        if (position == items.size) {
            holder.image.bind(null, null)
            holder.add.visibility = View.VISIBLE
            holder.ring.visibility = View.GONE
            holder.itemView.setOnClickListener { onAddMore() }
            return
        }
        val item = items[position]
        holder.add.visibility = View.GONE
        holder.ring.visibility = if (position == selected) View.VISIBLE else View.GONE
        // Drawn through the editor's own view, so a cropped or scribbled item
        // looks cropped and scribbled in the strip too.
        holder.image.bind(null, item)
        loader.bitmap(item.uri, item.isVideo, SIZE_PX) { bitmap ->
            if (holder.bindingAdapterPosition == position) holder.image.bind(bitmap, item)
        }
        holder.itemView.setOnClickListener { onSelect(position) }
    }

    private companion object {
        const val SIZE_PX = 160
    }
}
