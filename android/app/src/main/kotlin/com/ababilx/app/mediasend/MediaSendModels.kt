package com.ababilx.app.mediasend

import android.graphics.Path
import android.graphics.RectF
import android.net.Uri

/**
 * One picked item and everything the review screen has done to it.
 *
 * Edits are kept as *instructions*, never as a re-encoded bitmap: the user can
 * undo, re-crop and reorder for as long as the screen is open, and the single
 * flatten happens once, on send, in [MediaEditRenderer]. Signal keeps the same
 * separation between its editor model and the render it hands to the sender.
 */
class PickedItem(
    val uri: Uri,
    val name: String,
    val mime: String,
    val isVideo: Boolean,
    val sizeBytes: Long,
) {
    /** Quarter turns applied after decode, 0..3. */
    var rotationQuarters: Int = 0

    /**
     * Crop in normalised, pre-rotation image space (0..1). Null means the
     * whole frame.
     */
    var crop: RectF? = null

    val ops: MutableList<DrawOp> = mutableListOf()

    val edited: Boolean
        get() = rotationQuarters != 0 || crop != null || ops.isNotEmpty()

    fun copyEditsFrom(other: PickedItem) {
        rotationQuarters = other.rotationQuarters
        crop = other.crop?.let { RectF(it) }
        ops.clear()
        ops.addAll(other.ops)
    }
}

enum class DrawTool { PEN, HIGHLIGHT, BLUR }

/**
 * A stroke in normalised image space, so it survives zoom, rotation and the
 * difference between the preview's pixels and the exported file's.
 */
class DrawOp(
    val tool: DrawTool,
    val color: Int,
    /** Stroke width as a fraction of the image's shorter side. */
    val widthFraction: Float,
    val points: MutableList<Float> = mutableListOf(),
) {
    fun add(x: Float, y: Float) {
        points.add(x)
        points.add(y)
    }

    /** The stroke mapped onto a canvas of [w] x [h]. */
    fun toPath(w: Float, h: Float): Path {
        val path = Path()
        if (points.size < 2) return path
        path.moveTo(points[0] * w, points[1] * h)
        var i = 2
        while (i + 1 < points.size) {
            path.lineTo(points[i] * w, points[i + 1] * h)
            i += 2
        }
        return path
    }

    val isDot: Boolean get() = points.size == 2
}

/** What the gallery hands back for one row of the grid. */
class GalleryEntry(
    val uri: Uri,
    val name: String,
    val mime: String,
    val isVideo: Boolean,
    val sizeBytes: Long,
    val durationMs: Long,
)
