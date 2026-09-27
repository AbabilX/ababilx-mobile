package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.util.Log
import coil.ImageLoader
import coil.executeBlocking
import coil.request.ImageRequest
import coil.request.SuccessResult
import coil.size.Scale
import okhttp3.Cache
import okhttp3.OkHttpClient
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * Chat pictures for Direct Share, through Coil rather than a hand-rolled
 * download and decode: it downsamples while decoding, caches on disk and in
 * memory, and bounds both. Coil is already in the APK (the CallKit plugin
 * draws the caller's photo with it), so this costs no size.
 *
 * Its own loader and its own cache directory: two OkHttp caches must never
 * share one directory, and the plugin's loader uses Coil's default one.
 */
object DirectShareImages {

    private const val TAG = "DirectShare"
    private const val CACHE_DIR = "direct_share_images"
    private const val CACHE_BYTES = 10L * 1024 * 1024

    /** The hand-rolled cache this replaced; removed on the next prune. */
    private const val LEGACY_DIR = "direct_share_avatars"

    /** A picture that would not load is not asked for again this soon. */
    private const val RETRY_AFTER_MS = 15 * 60 * 1000L

    // Every publish runs on one worker; a dead CDN must not stall each of them
    // for the full timeout, eight times over.
    private val failedAt = ConcurrentHashMap<String, Long>()

    @Volatile
    private var cache: Cache? = null

    @Volatile
    private var loader: ImageLoader? = null

    /** A software bitmap at least [size] on its short side, or null. Blocking. */
    fun load(context: Context, url: String, size: Int): Bitmap? {
        if (!url.startsWith("https://")) return null
        val failed = failedAt[url]
        if (failed != null && System.currentTimeMillis() - failed < RETRY_AFTER_MS) return null
        val request = ImageRequest.Builder(context)
            .data(url)
            .size(size)
            .scale(Scale.FILL)
            // The icon is drawn onto a software Canvas and parcelled to the
            // launcher; a hardware bitmap can do neither.
            .allowHardware(false)
            .build()
        val bitmap = try {
            val result = loader(context).executeBlocking(request)
            ((result as? SuccessResult)?.drawable as? BitmapDrawable)?.bitmap
        } catch (error: Exception) {
            Log.w(TAG, "avatar load failed", error)
            null
        }
        if (bitmap == null) failedAt[url] = System.currentTimeMillis() else failedAt.remove(url)
        return bitmap
    }

    /** Drops cached pictures no current target uses (changed or gone). */
    fun prune(context: Context, urls: List<String>) {
        File(context.cacheDir, LEGACY_DIR).deleteRecursively()
        val keep = urls.filter { it.isNotEmpty() }.toSet()
        try {
            val cached = cache(context).urls()
            while (cached.hasNext()) {
                if (cached.next() !in keep) cached.remove()
            }
        } catch (error: Exception) {
            Log.w(TAG, "avatar prune failed", error)
        }
    }

    private fun cache(context: Context): Cache =
        cache ?: synchronized(this) {
            cache ?: Cache(File(context.cacheDir, CACHE_DIR), CACHE_BYTES).also { cache = it }
        }

    private fun loader(context: Context): ImageLoader =
        loader ?: synchronized(this) {
            loader ?: build(context.applicationContext).also { loader = it }
        }

    private fun build(context: Context): ImageLoader {
        val client = OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .cache(cache(context))
            .build()
        return ImageLoader.Builder(context)
            .okHttpClient(client)
            .crossfade(false)
            .build()
    }
}
