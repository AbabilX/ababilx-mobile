package com.ababilx.app.mediasend

import android.graphics.Bitmap
import android.net.Uri
import android.util.LruCache

/**
 * Decoded thumbnails, keyed by URI **and** size, with one trick: a request
 * that misses can still be served by downscaling a larger copy of the same
 * photo instead of decoding the original again.
 *
 * That trick is the whole reason this is not just an `LruCache`. The four
 * screens ask for four different sizes of the same picture — the grid at a
 * third of the screen width, the album covers at 192, the review rail at 160,
 * the pager and editor at the preview size — and a plain size-keyed cache
 * misses every time, so picking one photo used to decode it three times over.
 * Scaling down a bitmap already in memory costs microseconds; decoding a 12 MP
 * JPEG costs a fifth of a second and 30 MB of transient heap.
 *
 * Only *down*. Serving a 1600 px request from a 360 px cell would hand the
 * editor an upscaled blur to draw strokes onto.
 */
class ThumbnailCache {

    private val entries = object : LruCache<String, Bitmap>(
        (Runtime.getRuntime().maxMemory() / 1024 / 4).toInt().coerceAtLeast(4096),
    ) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount / 1024

        override fun entryRemoved(
            evicted: Boolean,
            key: String,
            oldValue: Bitmap,
            newValue: Bitmap?,
        ) {
            if (newValue == null) forget(key)
        }
    }

    /** Sizes held per URI, so a near-miss can be found without scanning. */
    private val sizes = HashMap<String, MutableList<Int>>()

    fun get(uri: Uri, sizePx: Int): Bitmap? {
        entries.get(key(uri, sizePx))?.let { return it }
        val larger = smallestAtLeast(uri, sizePx) ?: return null
        val source = entries.get(key(uri, larger)) ?: return null
        val scaled = downscale(source, sizePx)
        put(uri, sizePx, scaled)
        return scaled
    }

    fun put(uri: Uri, sizePx: Int, bitmap: Bitmap) {
        entries.put(key(uri, sizePx), bitmap)
        val held = sizes.getOrPut(uri.toString()) { mutableListOf() }
        if (!held.contains(sizePx)) {
            held.add(sizePx)
            held.sort()
        }
    }

    fun evictAll() {
        entries.evictAll()
        sizes.clear()
    }

    private fun smallestAtLeast(uri: Uri, sizePx: Int): Int? =
        sizes[uri.toString()]?.firstOrNull { it >= sizePx }

    private fun forget(key: String) {
        val at = key.lastIndexOf(SEPARATOR)
        if (at <= 0) return
        val uri = key.substring(0, at)
        val size = key.substring(at + 1).toIntOrNull() ?: return
        val held = sizes[uri] ?: return
        held.remove(size)
        if (held.isEmpty()) sizes.remove(uri)
    }

    /**
     * The bitmap handed back is a new one; the source stays in the cache and
     * must NOT be recycled, unlike the decode path where the original is ours
     * to throw away.
     */
    private fun downscale(source: Bitmap, sizePx: Int): Bitmap {
        val longest = maxOf(source.width, source.height)
        if (longest <= sizePx) return source
        val factor = sizePx.toFloat() / longest
        return Bitmap.createScaledBitmap(
            source,
            (source.width * factor).toInt().coerceAtLeast(1),
            (source.height * factor).toInt().coerceAtLeast(1),
            true,
        )
    }

    private fun key(uri: Uri, sizePx: Int) = "$uri$SEPARATOR$sizePx"

    private companion object {
        const val SEPARATOR = '@'
    }
}
