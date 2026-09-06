package com.ababilx.app.mediasend

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import kotlin.math.max

/**
 * Decoding, upright and downsampled.
 *
 * Two rules the whole flow depends on: nothing is ever decoded at full size
 * for display (a 12 MP photo in a 96 dp cell is 40 MB of heap for nothing),
 * and every bitmap that leaves here is already EXIF-rotated — so the editor,
 * the crop rectangle and the exported file all agree on which way is up.
 */
object MediaBitmaps {

    fun decode(context: Context, uri: Uri, maxPx: Int): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        }
        val longest = max(bounds.outWidth, bounds.outHeight)
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(longest, maxPx)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val raw = context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        }
        raw?.let { upright(context, uri, it) }
    } catch (_: Exception) {
        null
    } catch (_: OutOfMemoryError) {
        null
    }

    fun videoFrame(context: Context, uri: Uri): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            retriever.frameAtTime
        } catch (_: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // The frame either arrived or it did not.
            }
        }
    }

    /**
     * A thumbnail-sized bitmap for a cell or a strip.
     *
     * [FastThumbnail] first, because a grid asks for this once per photo and
     * the provider's cached thumbnail is an order of magnitude cheaper than
     * decoding the original — most of all for a video, where the slow path is
     * a full [MediaMetadataRetriever] frame extraction. Anything it cannot
     * serve (a `file://` URI, a size too large to be a thumbnail, API 28)
     * falls through to the decode below.
     */
    fun preview(context: Context, uri: Uri, isVideo: Boolean, maxPx: Int): Bitmap? {
        FastThumbnail.of(context, uri, maxPx)?.let { return it }
        return if (isVideo) videoFrame(context, uri) else decode(context, uri, maxPx)
    }

    fun rotate(source: Bitmap, degrees: Int): Bitmap {
        if (degrees % 360 == 0) return source
        val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
        val out = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        if (out != source) source.recycle()
        return out
    }

    private fun sampleSize(longest: Int, maxPx: Int): Int {
        if (maxPx <= 0 || longest <= maxPx) return 1
        var sample = 1
        while (longest / (sample * 2) >= maxPx) sample *= 2
        return sample
    }

    /**
     * JPEGs from a phone camera are almost always stored sideways with an EXIF
     * tag telling the viewer to turn them. A canvas does not read that tag, so
     * a stroke drawn on an un-rotated preview would land in the wrong place on
     * the exported file.
     */
    private fun upright(context: Context, uri: Uri, bitmap: Bitmap): Bitmap = try {
        val degrees = context.contentResolver.openInputStream(uri)?.use { input ->
            when (
                ExifInterface(input).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } ?: 0
        rotate(bitmap, degrees)
    } catch (_: Exception) {
        bitmap
    }
}
