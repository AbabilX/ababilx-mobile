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
 * One page per picked item, drawn by the same view the editor uses — so an
 * edit made and confirmed is on screen the instant the editor closes, with no
 * re-decode and no flash of the original.
 */
class ReviewPagerAdapter(
    private val items: List<PickedItem>,
    private val loader: ThumbnailLoader,
    private val previewPx: Int,
) : RecyclerView.Adapter<ReviewPagerAdapter.Page>() {

    class Page(view: View) : RecyclerView.ViewHolder(view) {
        val image: EditableImageView = view.findViewById(R.id.page_image)
        val play: ImageView = view.findViewById(R.id.page_play)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Page = Page(
        LayoutInflater.from(parent.context)
            .inflate(R.layout.media_send_review_page, parent, false),
    )

    override fun getItemCount() = items.size

    override fun onBindViewHolder(holder: Page, position: Int) {
        val item = items[position]
        holder.play.visibility = if (item.isVideo) View.VISIBLE else View.GONE
        holder.image.mode = EditableImageView.Mode.VIEW
        holder.image.bind(null, item)
        loader.bitmap(item.uri, item.isVideo, previewPx) { bitmap ->
            // The page may have been recycled onto a different item while the
            // decode was in flight.
            if (holder.bindingAdapterPosition == position) holder.image.bind(bitmap, item)
        }
    }
}
