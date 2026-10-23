package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import com.ababilx.app.mediasend.FastThumbnail
import java.io.ByteArrayOutputStream
import kotlin.math.max

/**
 * Previews for the share screen, decoded straight from the original content
 * URI.
 *
 * Drawing a 72dp tile must not cost a full-size copy: images are downsampled
 * during decode and a video contributes one frame. Split from
 * [ShareIntakeBridge] so intent parsing stays free of bitmap handling.
 */
object ShareThumbnails {

    private const val JPEG_QUALITY = 82

    /**
     * A small JPEG preview of an image or video, decoded straight from the
     * original. Drawing a 72dp tile must not cost a full-size copy.
     */
    fun of(context: Context, uriString: String, maxPx: Int): ByteArray? {
        val uri = Uri.parse(uriString)
        if (!ShareUriPolicy.acceptForRead(context, uri)) return null
        // MediaProvider's own cached thumbnail, when this is a library item.
        // It costs one call instead of a getType() lookup plus two or three
        // stream opens, and for a video it replaces a full frame extraction —
        // which is what made a strip of forty recents take seconds to fill.
        FastThumbnail.of(context, uri, maxPx)?.let { return jpeg(it) }
        val mime = try {
            context.contentResolver.getType(uri).orEmpty()
        } catch (_: Exception) {
            ""
        }
        val bitmap = when {
            mime.startsWith("video/") -> videoFrame(context, uri, maxPx)
            mime.startsWith("image/") -> imageBitmap(context, uri, maxPx)
            else -> null
        } ?: return null
        return jpeg(bitmap)
    }

    private fun jpeg(bitmap: Bitmap): ByteArray =
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            bitmap.recycle()
            out.toByteArray()
        }

    private fun imageBitmap(context: Context, uri: Uri, maxPx: Int): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        }
        val longest = max(bounds.outWidth, bounds.outHeight)
        val options = BitmapFactory.Options().apply { inSampleSize = sampleSize(longest, maxPx) }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        }
    } catch (_: Exception) {
        null
    }

    /**
     * `inSampleSize` is rounded DOWN to a power of two by BitmapFactory, so
     * the obvious `longest / maxPx` decodes up to twice the intended edge —
     * four times the pixels. Doubling until the next step would overshoot is
     * the only form that actually honours [maxPx].
     */
    private fun sampleSize(longest: Int, maxPx: Int): Int {
        if (maxPx <= 0 || longest <= maxPx) return 1
        var sample = 1
        while (longest / (sample * 2) >= maxPx) sample *= 2
        return sample
    }

    /**
     * A frame, downscaled by the extractor where the platform can do it.
     * [MediaMetadataRetriever.frameAtTime] hands back the video's full
     * resolution — a 4K frame is 33 MB of heap for a 72 dp tile.
     */
    private fun videoFrame(context: Context, uri: Uri, maxPx: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1 && maxPx > 0) {
                retriever.getScaledFrameAtTime(
                    0,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    maxPx,
                    maxPx,
                ) ?: retriever.frameAtTime
            } else {
                retriever.frameAtTime
            }
        } catch (_: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // Nothing useful to do; the frame either arrived or it did not.
            }
        }
    }
}
