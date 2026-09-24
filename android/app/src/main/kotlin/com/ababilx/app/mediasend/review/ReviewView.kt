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
import com.ababilx.app.mediasend.MediaQuality
import com.ababilx.app.mediasend.MediaSendContentFit
import com.ababilx.app.mediasend.PickedItem
import com.ababilx.app.mediasend.ThumbnailLoader

/**
 * What you see after picking: the album full-screen, the strip of everything
 * chosen, one message for the whole send, and Send. One caption for the
 * album, not one per image — Signal's flow, and our send API's only shape.
 */
class ReviewView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    var onBack: (() -> Unit)? = null

    /** The three ways "+ Add more" can go. The sheet decides which. */
    var onAddCamera: (() -> Unit)? = null
    var onAddGallery: (() -> Unit)? = null
    var onAddFiles: (() -> Unit)? = null
    var onEditRequested: ((PickedItem) -> Unit)? = null
    var onSend: ((List<PickedItem>, String, MediaQuality) -> Unit)? = null
    var onEmptied: (() -> Unit)? = null

    /** The eye beside Remove: the wiring sets `allowed`, finish reads `on`. */
    val viewOnce: ViewOnceToggle

    /** Level the next send will use. Handed back so Dart can remember it. */
    var quality: MediaQuality = MediaQuality.STANDARD
        set(value) {
            field = value
            refreshQuality()
        }

    private val pager: ViewPager2
    private val rail: RecyclerView
    private val caption: EditText
    private val count: TextView
    private val qualityButton: TextView
    private val qualitySheet: QualitySheetView
    private val addSheet: AddMoreSheetView
    private val editButton: ImageButton

    private val items = mutableListOf<PickedItem>()
    private lateinit var pagerAdapter: ReviewPagerAdapter
    private lateinit var railAdapter: RailAdapter

    init {
        LayoutInflater.from(context).inflate(R.layout.media_send_review, this, true)
        pager = findViewById(R.id.review_pager)
        rail = findViewById(R.id.review_rail)
        caption = findViewById(R.id.review_caption)
        count = findViewById(R.id.review_count)
        qualityButton = findViewById(R.id.review_quality)
        qualitySheet = findViewById(R.id.review_quality_sheet)
        qualityButton.setOnClickListener { qualitySheet.show(quality) }
        qualitySheet.onPicked = { quality = it }
        refreshQuality()

        addSheet = findViewById(R.id.review_add_sheet)
        addSheet.onCamera = { onAddCamera?.invoke() }
        addSheet.onGallery = { onAddGallery?.invoke() }
        addSheet.onFiles = { onAddFiles?.invoke() }

        findViewById<ImageButton>(R.id.review_back).setOnClickListener { onBack?.invoke() }
        editButton = findViewById(R.id.review_edit)
        editButton.setOnClickListener {
            current()?.let { onEditRequested?.invoke(it) }
        }
        findViewById<TextView>(R.id.review_remove).setOnClickListener { removeCurrent() }
        viewOnce = ViewOnceToggle(findViewById(R.id.review_view_once))
        findViewById<ImageButton>(R.id.review_send).setOnClickListener {
            if (items.isNotEmpty()) {
                onSend?.invoke(items.toList(), caption.text.toString().trim(), quality)
            }
        }

        pager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                if (::railAdapter.isInitialized) railAdapter.selected = position
                rail.smoothScrollToPosition(position)
                refreshEditable()
            }
        })

        MediaSendContentFit.chrome(this, pager, R.id.review_topbar, R.id.review_bottombar)
    }

    fun attach(loader: ThumbnailLoader, previewPx: Int) {
        if (::pagerAdapter.isInitialized) return
        pagerAdapter = ReviewPagerAdapter(items, loader, previewPx)
        railAdapter = RailAdapter(
            items,
            loader,
            onSelect = { pager.setCurrentItem(it, true) },
            onAddMore = { addSheet.show() },
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
        refreshEditable()
    }

    /** After the editor commits: redraw the page and its thumbnail. */
    fun refreshCurrent() {
        val position = pager.currentItem
        pagerAdapter.notifyItemChanged(position)
        railAdapter.notifyItemChanged(position)
    }

    /** @return true when a sheet was open and this press closed it. */
    fun dismissSheet(): Boolean {
        if (addSheet.isShowing) {
            addSheet.hide()
            return true
        }
        if (qualitySheet.isShowing) {
            qualitySheet.hide()
            return true
        }
        return false
    }

    fun current(): PickedItem? = items.getOrNull(pager.currentItem)

    fun selection(): List<PickedItem> = items.toList()

    fun setCaption(text: String) {
        caption.setText(text)
        caption.setSelection(text.length)
    }

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
        refreshEditable()
    }

    /** The editor exports a JPEG and a video is copied untouched, so an
     *  edit on a video frame would be thrown away: hide the button. */
    private fun refreshEditable() {
        val editable = current()?.isVideo == false
        editButton.visibility = if (editable) View.VISIBLE else View.GONE
    }

    private fun refreshQuality() {
        qualityButton.text = context.getString(
            if (quality == MediaQuality.HIGH) {
                R.string.media_send_quality_high_short
            } else {
                R.string.media_send_quality_standard_short
            },
        )
    }

    private fun refreshCount() {
        count.visibility = if (items.size > 1) View.VISIBLE else View.GONE
        count.text = items.size.toString()
        viewOnce.refresh(items)
    }
}
