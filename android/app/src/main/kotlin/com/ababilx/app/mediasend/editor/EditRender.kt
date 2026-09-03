package com.ababilx.app.mediasend.editor

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import com.ababilx.app.mediasend.DrawOp
import com.ababilx.app.mediasend.DrawTool
import com.ababilx.app.mediasend.PickedItem
import kotlin.math.max
import kotlin.math.min

/**
 * The single definition of what an edited image looks like.
 *
 * The preview on screen and the JPEG that is actually sent are produced by the
 * *same* functions here, differing only in the canvas they are handed. That is
 * the whole reason strokes are stored normalised: a stroke drawn on a 1080 px
 * preview lands on exactly the same pixels of a 4000 px export.
 */
object EditRender {

    /** How far down the original is scaled before being blown back up. */
    private const val BLUR_DOWNSCALE = 14

    /**
     * Maps original-bitmap pixels onto [bounds], honouring the item's crop and
     * rotation. Everything else — touch handling, stroke rendering, the crop
     * overlay — works through this one matrix and its inverse.
     */
    fun displayMatrix(item: PickedItem, srcW: Int, srcH: Int, bounds: RectF): Matrix {
        val crop = cropPixels(item, srcW, srcH)
        val matrix = Matrix()
        matrix.postTranslate(-crop.left, -crop.top)
        matrix.postRotate(item.rotationQuarters * 90f)

        val box = RectF(0f, 0f, crop.width(), crop.height())
        Matrix().apply { postRotate(item.rotationQuarters * 90f) }.mapRect(box)
        matrix.postTranslate(-box.left, -box.top)

        val scale = min(bounds.width() / box.width(), bounds.height() / box.height())
        matrix.postScale(scale, scale)
        matrix.postTranslate(
            bounds.left + (bounds.width() - box.width() * scale) / 2f,
            bounds.top + (bounds.height() - box.height() * scale) / 2f,
        )
        return matrix
    }

    /** The crop rectangle in original pixels; the whole frame when unset. */
    fun cropPixels(item: PickedItem, srcW: Int, srcH: Int): RectF {
        val c = item.crop ?: return RectF(0f, 0f, srcW.toFloat(), srcH.toFloat())
        return RectF(c.left * srcW, c.top * srcH, c.right * srcW, c.bottom * srcH)
    }

    /**
     * Draws the image and its strokes in *original pixel* space. The caller
     * has already concat'd [displayMatrix] (preview) or a plain scale matrix
     * (export), so this code never has to know which one it is drawing for.
     */
    fun drawContent(
        canvas: Canvas,
        source: Bitmap,
        item: PickedItem,
        blurred: Bitmap?,
    ) {
        canvas.drawBitmap(source, 0f, 0f, null)
        if (item.ops.isEmpty()) return
        val unit = min(source.width, source.height).toFloat()
        for (op in item.ops) {
            val paint = paintFor(op, unit, source, blurred) ?: continue
            if (op.isDot) {
                canvas.drawPoint(op.points[0] * source.width, op.points[1] * source.height, paint)
            } else {
                canvas.drawPath(op.toPath(source.width.toFloat(), source.height.toFloat()), paint)
            }
        }
    }

    private fun paintFor(op: DrawOp, unit: Float, source: Bitmap, blurred: Bitmap?): Paint? {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            strokeWidth = max(1f, op.widthFraction * unit)
        }
        when (op.tool) {
            DrawTool.PEN -> paint.color = op.color
            DrawTool.HIGHLIGHT -> {
                paint.color = op.color
                paint.alpha = 110
            }
            DrawTool.BLUR -> {
                val layer = blurred ?: return null
                // The stroke is painted *with the blurred image itself*, so the
                // face under it is replaced by its own smeared pixels — no
                // clipping, no extra layer, and it exports identically.
                paint.shader = BitmapShader(layer, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                    .apply {
                        setLocalMatrix(
                            Matrix().apply {
                                setScale(
                                    source.width.toFloat() / layer.width,
                                    source.height.toFloat() / layer.height,
                                )
                            },
                        )
                    }
            }
        }
        return paint
    }

    /**
     * A cheap blur: shrink hard, grow back with filtering. Faster than a real
     * kernel at these sizes and, unlike RenderScript, still supported.
     */
    fun blurLayer(source: Bitmap): Bitmap? = try {
        val w = max(1, source.width / BLUR_DOWNSCALE)
        val h = max(1, source.height / BLUR_DOWNSCALE)
        val small = Bitmap.createScaledBitmap(source, w, h, true)
        val out = Bitmap.createBitmap(w * 2, h * 2, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(
            small,
            Rect(0, 0, w, h),
            Rect(0, 0, w * 2, h * 2),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        small.recycle()
        out
    } catch (_: OutOfMemoryError) {
        null
    }

    /** Flattens one item into the bitmap that will actually be uploaded. */
    fun export(source: Bitmap, item: PickedItem): Bitmap {
        val crop = cropPixels(item, source.width, source.height)
        val box = RectF(0f, 0f, crop.width(), crop.height())
        Matrix().apply { postRotate(item.rotationQuarters * 90f) }.mapRect(box)

        val out = Bitmap.createBitmap(
            max(1, box.width().toInt()),
            max(1, box.height().toInt()),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(out)
        canvas.drawColor(Color.BLACK)
        canvas.concat(displayMatrix(item, source.width, source.height, RectF(0f, 0f, out.width.toFloat(), out.height.toFloat())))
        canvas.clipRect(crop)
        drawContent(canvas, source, item, if (item.ops.any { it.tool == DrawTool.BLUR }) blurLayer(source) else null)
        return out
    }
}
