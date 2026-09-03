package com.ababilx.app.mediasend.review

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.viewpager2.widget.ViewPager2
import com.ababilx.app.R
import com.ababilx.app.mediasend.MediaSendInsets
import com.ababilx.app.mediasend.PickedItem
import com.ababilx.app.mediasend.ThumbnailLoader

/**
 * What you see after picking: the album full-screen, the strip of everything
 * chosen, one message for the whole send, and Send.
 *
 * The message is deliberately **one caption for the album**, not one per
 * image — that is how Signal's current flow behaves, and it is also the only
 * shape our send API has (a body plus attachments).
 */
class ReviewView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    var onBack: (() -> Unit)? = null
    var onAddMore: (() -> Unit)? = null
    var onEditRequested: ((PickedItem) -> Unit)? = null
    var onSend: ((List<PickedItem>, String) -> Unit)? = null
    var onEmptied: (() -> Unit)? = null

    private val pager: ViewPager2
    private val rail: RecyclerView
    private val caption: EditText
    private val count: TextView

    private val items = mutableListOf<PickedItem>()
    private lateinit var pagerAdapter: ReviewPagerAdapter
    private lateinit var railAdapter: RailAdapter

    init {
        LayoutInflater.from(context).inflate(R.layout.media_send_review, this, true)
        pager = findViewById(R.id.review_pager)
        rail = findViewById(R.id.review_rail)
        caption = findViewById(R.id.review_caption)
        count = findViewById(R.id.review_count)

        findViewById<ImageButton>(R.id.review_back).setOnClickListener { onBack?.invoke() }
        findViewById<ImageButton>(R.id.review_edit).setOnClickListener {
            current()?.let { onEditRequested?.invoke(it) }
        }
        findViewById<ImageButton>(R.id.review_remove).setOnClickListener { removeCurrent() }
        findViewById<ImageButton>(R.id.review_send).setOnClickListener {
            if (items.isNotEmpty()) onSend?.invoke(items.toList(), caption.text.toString().trim())
        }

        pager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                if (::railAdapter.isInitialized) railAdapter.selected = position
                rail.smoothScrollToPosition(position)
            }
        })

        MediaSendInsets.padTop(findViewById(R.id.review_topbar))
        MediaSendInsets.padBottom(findViewById(R.id.review_bottombar))
    }

    fun attach(loader: ThumbnailLoader, previewPx: Int) {
        if (::pagerAdapter.isInitialized) return
        pagerAdapter = ReviewPagerAdapter(items, loader, previewPx)
        railAdapter = RailAdapter(
            items,
            loader,
            onSelect = { pager.setCurrentItem(it, true) },
            onAddMore = { onAddMore?.invoke() },
        )
        pager.adapter = pagerAdapter
        rail.layoutManager = LinearLayoutManager(context, RecyclerView.HORIZONTAL, false)
        rail.adapter = railAdapter
    }

    /** Replaces the whole selection — what the gallery hands back. */
    fun show(next: List<PickedItem>, focus: Int = 0) {
        items.clear()
        items.addAll(next)
        pagerAdapter.notifyDataSetChanged()
        railAdapter.notifyDataSetChanged()
        val target = focus.coerceIn(0, (items.size - 1).coerceAtLeast(0))
        pager.setCurrentItem(target, false)
        railAdapter.selected = target
        refreshCount()
    }

    /** After the editor commits: redraw the page and its thumbnail. */
    fun refreshCurrent() {
        val position = pager.currentItem
        pagerAdapter.notifyItemChanged(position)
        railAdapter.notifyItemChanged(position)
    }

    fun current(): PickedItem? = items.getOrNull(pager.currentItem)

    fun selection(): List<PickedItem> = items.toList()

    private fun removeCurrent() {
        val position = pager.currentItem
        if (position !in items.indices) return
        items.removeAt(position)
        pagerAdapter.notifyItemRemoved(position)
        railAdapter.notifyDataSetChanged()
        if (items.isEmpty()) {
            onEmptied?.invoke()
            return
        }
        val next = position.coerceAtMost(items.size - 1)
        pager.setCurrentItem(next, false)
        railAdapter.selected = next
        refreshCount()
    }

    private fun refreshCount() {
        count.visibility = if (items.size > 1) View.VISIBLE else View.GONE
        count.text = items.size.toString()
    }
}
