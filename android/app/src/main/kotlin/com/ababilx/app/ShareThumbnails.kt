package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
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
        val mime = try {
            context.contentResolver.getType(uri).orEmpty()
        } catch (_: Exception) {
            ""
        }
        val bitmap = when {
            mime.startsWith("video/") -> videoFrame(context, uri)
            mime.startsWith("image/") -> imageBitmap(context, uri, maxPx)
            else -> null
        } ?: return null

        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }

    private fun imageBitmap(context: Context, uri: Uri, maxPx: Int): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        }
        val longest = max(bounds.outWidth, bounds.outHeight)
        val options = BitmapFactory.Options().apply {
            inSampleSize = if (longest > maxPx && maxPx > 0) longest / maxPx else 1
        }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        }
    } catch (_: Exception) {
        null
    }

    private fun videoFrame(context: Context, uri: Uri): Bitmap? {
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
                // Nothing useful to do; the frame either arrived or it did not.
            }
        }
    }
}
