package com.ababilx.app.mediasend.editor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import com.ababilx.app.R
import com.ababilx.app.mediasend.DrawTool
import com.ababilx.app.mediasend.MediaSendInsets
import com.ababilx.app.mediasend.PickedItem

/**
 * Signal's editor chrome: the picture, a tool row, and a colour strip that
 * only exists while a drawing tool is selected.
 *
 * Cancel restores the edits the item had on entry, which is why they are
 * snapshotted into a scratch [PickedItem] rather than mutated in place until
 * Done is pressed.
 */
class EditorView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    var onDone: ((PickedItem) -> Unit)? = null
    var onCancel: (() -> Unit)? = null

    private val canvas: EditableImageView
    private val colors: LinearLayout
    private val tools = mutableMapOf<DrawTool, ImageButton>()
    private val cropButton: ImageButton

    private var target: PickedItem? = null
    private val scratch = PickedItem(android.net.Uri.EMPTY, "", "", false, 0)
    private var cropping = false

    init {
        LayoutInflater.from(context).inflate(R.layout.media_send_editor, this, true)
        canvas = findViewById(R.id.editor_canvas)
        colors = findViewById(R.id.editor_colors)
        cropButton = findViewById(R.id.tool_crop)
        tools[DrawTool.PEN] = findViewById(R.id.tool_pen)
        tools[DrawTool.HIGHLIGHT] = findViewById(R.id.tool_highlight)
        tools[DrawTool.BLUR] = findViewById(R.id.tool_blur)

        findViewById<ImageButton>(R.id.editor_cancel).setOnClickListener { onCancel?.invoke() }
        findViewById<ImageButton>(R.id.editor_undo).setOnClickListener { canvas.undo() }
        findViewById<ImageButton>(R.id.editor_done).setOnClickListener { finish() }
        findViewById<ImageButton>(R.id.tool_rotate).setOnClickListener { canvas.rotate() }
        cropButton.setOnClickListener { toggleCrop() }
        for ((tool, button) in tools) button.setOnClickListener { selectTool(tool) }

        buildColorStrip()
        selectTool(DrawTool.PEN)

        MediaSendInsets.padTop(findViewById(R.id.editor_topbar))
        MediaSendInsets.padBottom(findViewById(R.id.editor_bottombar))
    }

    fun open(bitmap: Bitmap?, item: PickedItem) {
        target = item
        scratch.copyEditsFrom(item)
        cropping = false
        canvas.bind(bitmap, item)
        canvas.mode = EditableImageView.Mode.DRAW
        selectTool(DrawTool.PEN)
        refreshCropButton()
    }

    /** Cancel: put back what the item looked like before this session. */
    fun revert() {
        target?.copyEditsFrom(scratch)
        canvas.refresh()
    }

    private fun finish() {
        if (cropping) {
            canvas.commitCrop()
            toggleCrop()
            return
        }
        target?.let { onDone?.invoke(it) }
    }

    private fun toggleCrop() {
        cropping = !cropping
        canvas.mode = if (cropping) EditableImageView.Mode.CROP else EditableImageView.Mode.DRAW
        colors.visibility = if (cropping) GONE else VISIBLE
        refreshCropButton()
    }

    private fun refreshCropButton() {
        cropButton.setBackgroundResource(
            if (cropping) R.drawable.ms_circle_accent else R.drawable.ms_circle_button,
        )
    }

    private fun selectTool(tool: DrawTool) {
        if (cropping) toggleCrop()
        canvas.tool = tool
        canvas.mode = EditableImageView.Mode.DRAW
        for ((key, button) in tools) {
            button.setBackgroundResource(
                if (key == tool) R.drawable.ms_circle_accent else R.drawable.ms_circle_button,
            )
        }
        // Blur has no colour of its own — it paints with the photo.
        colors.visibility = if (tool == DrawTool.BLUR) GONE else VISIBLE
    }

    private fun buildColorStrip() {
        val size = (32 * resources.displayMetrics.density).toInt()
        val gap = (6 * resources.displayMetrics.density).toInt()
        for (color in PALETTE) {
            val swatch = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(size, size).also {
                    it.marginStart = gap
                    it.marginEnd = gap
                }
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.OVAL
                    setColor(color)
                    setStroke((2 * resources.displayMetrics.density).toInt(), Color.WHITE)
                }
                setOnClickListener {
                    canvas.strokeColor = color
                    for (i in 0 until colors.childCount) {
                        colors.getChildAt(i).alpha = 0.45f
                    }
                    alpha = 1f
                }
                alpha = 0.45f
            }
            colors.addView(swatch)
        }
        colors.getChildAt(0)?.alpha = 1f
        canvas.strokeColor = PALETTE.first()
    }

    private companion object {
        val PALETTE = listOf(
            0xFFFF3B30.toInt(),
            0xFFFFCC00.toInt(),
            0xFF34C759.toInt(),
            0xFF0A84FF.toInt(),
            0xFFAF52DE.toInt(),
            0xFFFFFFFF.toInt(),
            0xFF000000.toInt(),
        )
    }
}
