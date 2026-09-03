package com.ababilx.app.mediasend.editor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.ababilx.app.mediasend.DrawOp
import com.ababilx.app.mediasend.DrawTool
import com.ababilx.app.mediasend.PickedItem

/**
 * One picture, drawn with its edits applied, in every place the flow shows it.
 *
 * The review pager uses it read-only ([Mode.VIEW]); the editor turns on
 * [Mode.DRAW] or [Mode.CROP]. Keeping it one view is what makes tapping Done
 * feel instant — the page behind the editor is already rendering from the same
 * model, so there is nothing to reload.
 */
class EditableImageView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    enum class Mode { VIEW, DRAW, CROP }

    var mode: Mode = Mode.VIEW
        set(value) {
            field = value
            if (value == Mode.CROP) resetCropBox()
            invalidate()
        }

    var tool: DrawTool = DrawTool.PEN
    var strokeColor: Int = 0xFFFF3B30.toInt()
    var onEdited: (() -> Unit)? = null

    private var source: Bitmap? = null
    private var item: PickedItem? = null
    private var blurred: Bitmap? = null
    private var active: DrawOp? = null
    private val crop = CropBox()
    private val inverse = Matrix()

    fun bind(bitmap: Bitmap?, model: PickedItem?) {
        source = bitmap
        item = model
        blurred = null
        active = null
        invalidate()
    }

    /** Committed edits are on [item]; this is only the redraw signal. */
    fun refresh() = invalidate()

    fun undo() {
        val ops = item?.ops ?: return
        if (ops.isNotEmpty()) {
            ops.removeAt(ops.size - 1)
            onEdited?.invoke()
            invalidate()
        }
    }

    fun rotate() {
        val model = item ?: return
        model.rotationQuarters = (model.rotationQuarters + 1) % 4
        if (mode == Mode.CROP) resetCropBox()
        onEdited?.invoke()
        invalidate()
    }

    /** Turns the on-screen crop box into normalised image coordinates. */
    fun commitCrop() {
        val model = item ?: return
        val bitmap = source ?: return
        val matrix = displayMatrix(bitmap) ?: return
        val out = Matrix()
        if (!matrix.invert(out)) return
        val box = RectF(crop.rect)
        out.mapRect(box)
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()
        model.crop = RectF(
            (box.left / w).coerceIn(0f, 1f),
            (box.top / h).coerceIn(0f, 1f),
            (box.right / w).coerceIn(0f, 1f),
            (box.bottom / h).coerceIn(0f, 1f),
        )
        onEdited?.invoke()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val bitmap = source ?: return
        val model = item ?: return
        val matrix = displayMatrix(bitmap) ?: return
        if (model.ops.any { it.tool == DrawTool.BLUR } && blurred == null) {
            blurred = EditRender.blurLayer(bitmap)
        }
        canvas.save()
        canvas.concat(matrix)
        canvas.clipRect(EditRender.cropPixels(model, bitmap.width, bitmap.height))
        EditRender.drawContent(canvas, bitmap, model, blurred)
        canvas.restore()
        if (mode == Mode.CROP) crop.draw(canvas, imageBounds(bitmap, matrix))
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // The mode can be set before the first layout, when there is no
        // geometry to size the crop box against.
        if (mode == Mode.CROP) resetCropBox()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val bitmap = source ?: return false
        val model = item ?: return false
        when (mode) {
            Mode.VIEW -> return false
            Mode.CROP -> {
                val bounds = imageBounds(bitmap, displayMatrix(bitmap) ?: return false)
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> crop.down(event.x, event.y)
                    MotionEvent.ACTION_MOVE -> {
                        crop.move(event.x, event.y, bounds)
                        invalidate()
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> crop.up()
                }
                parent?.requestDisallowInterceptTouchEvent(true)
                return true
            }
            Mode.DRAW -> return draw(event, bitmap, model)
        }
    }

    private fun draw(event: MotionEvent, bitmap: Bitmap, model: PickedItem): Boolean {
        val matrix = displayMatrix(bitmap) ?: return false
        if (!matrix.invert(inverse)) return false
        val point = floatArrayOf(event.x, event.y)
        inverse.mapPoints(point)
        val nx = point[0] / bitmap.width
        val ny = point[1] / bitmap.height

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                val op = DrawOp(tool, strokeColor, widthFor(tool))
                op.add(nx, ny)
                model.ops.add(op)
                active = op
                parent?.requestDisallowInterceptTouchEvent(true)
            }
            MotionEvent.ACTION_MOVE -> active?.add(nx, ny)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                active = null
                onEdited?.invoke()
            }
        }
        invalidate()
        return true
    }

    private fun widthFor(tool: DrawTool) = when (tool) {
        DrawTool.PEN -> 0.012f
        DrawTool.HIGHLIGHT -> 0.05f
        DrawTool.BLUR -> 0.09f
    }

    private fun displayMatrix(bitmap: Bitmap): Matrix? {
        val model = item ?: return null
        if (width == 0 || height == 0) return null
        return EditRender.displayMatrix(
            model,
            bitmap.width,
            bitmap.height,
            RectF(0f, 0f, width.toFloat(), height.toFloat()),
        )
    }

    private fun imageBounds(bitmap: Bitmap, matrix: Matrix): RectF {
        val model = item ?: return RectF(0f, 0f, width.toFloat(), height.toFloat())
        val box = EditRender.cropPixels(model, bitmap.width, bitmap.height)
        val out = RectF(box)
        matrix.mapRect(out)
        return out
    }

    private fun resetCropBox() {
        val bitmap = source ?: return
        val matrix = displayMatrix(bitmap) ?: return
        crop.reset(imageBounds(bitmap, matrix))
    }
}
