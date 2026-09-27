package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.graphics.drawable.IconCompat
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/**
 * The round picture on a Direct Share target. The system draws the AbabilX
 * badge over its corner itself.
 *
 * A circle bitmap at the adaptive icon's inner size, as Signal's
 * `getIconCompatForShortcut` does: the share sheet draws it as-is, so the
 * transparent corners are what make it round. Pictures are downloaded once
 * into the cache; a chat with none, or one that will not load, gets initials.
 */
object DirectShareAvatars {

    private const val MAX_BYTES = 2L * 1024 * 1024
    private const val DIR = "direct_share_avatars"

    /** A picture that would not load is not asked for again this soon. */
    private const val RETRY_AFTER_MS = 15 * 60 * 1000L

    // Every publish runs on one worker; a dead CDN must not stall each of them
    // for the full timeout, eight times over.
    private val failedAt = ConcurrentHashMap<String, Long>()

    private val PALETTE = intArrayOf(
        0xFF5C6BC0.toInt(),
        0xFF26A69A.toInt(),
        0xFFEF6C00.toInt(),
        0xFFAB47BC.toInt(),
        0xFF42A5F5.toInt(),
        0xFFEC407A.toInt(),
        0xFF66BB6A.toInt(),
        0xFF8D6E63.toInt(),
    )

    fun icon(context: Context, target: DirectShareShortcuts.Target): IconCompat {
        // 72dp is the visible part of a 108dp adaptive icon.
        val size = (context.resources.displayMetrics.density * 72).toInt().coerceIn(96, 288)
        val bitmap = photo(context, target.avatarUrl, size) ?: initials(target, size)
        return IconCompat.createWithBitmap(bitmap)
    }

    /** A plain grey disc: what a retired pinned shortcut is repainted with. */
    fun blank(context: Context): IconCompat {
        val size = (context.resources.displayMetrics.density * 72).toInt().coerceIn(96, 288)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.LTGRAY }
        Canvas(out).drawCircle(size / 2f, size / 2f, size / 2f, fill)
        return IconCompat.createWithBitmap(out)
    }

    /** Drops cached pictures no current target uses (changed or gone). */
    fun prune(context: Context, urls: List<String>) {
        val keep = urls.filter { it.isNotEmpty() }.map(::sha256).toSet()
        File(context.cacheDir, DIR).listFiles()?.forEach { file ->
            if (file.name !in keep) file.delete()
        }
    }

    private fun photo(context: Context, url: String, size: Int): Bitmap? {
        if (!url.startsWith("https://")) return null
        val failed = failedAt[url]
        if (failed != null && System.currentTimeMillis() - failed < RETRY_AFTER_MS) return null
        val file = cached(context, url)
        if (file == null) {
            failedAt[url] = System.currentTimeMillis()
            return null
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            // A captive portal's HTML answers 200 too; do not keep it forever.
            file.delete()
            failedAt[url] = System.currentTimeMillis()
            return null
        }
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= size && bounds.outHeight / (sample * 2) >= size) {
            sample *= 2
        }
        val decoded = BitmapFactory.decodeFile(
            file.path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        failedAt.remove(url)
        return circle(decoded, size)
    }

    /** One download per picture; the file name is a hash, never the URL. */
    private fun cached(context: Context, url: String): File? {
        val dir = File(context.cacheDir, DIR).apply { mkdirs() }
        val file = File(dir, sha256(url))
        if (file.length() > 0) return file
        val partial = File(dir, "${file.name}.part")
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 5_000
            connection.readTimeout = 10_000
            try {
                if (connection.responseCode != HttpURLConnection.HTTP_OK) return null
                if (connection.contentLengthLong > MAX_BYTES) return null
                connection.inputStream.use { input ->
                    partial.outputStream().use { output ->
                        val buffer = ByteArray(16 * 1024)
                        var total = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            total += read
                            if (total > MAX_BYTES) return null
                            output.write(buffer, 0, read)
                        }
                    }
                }
            } finally {
                connection.disconnect()
            }
            if (partial.renameTo(file)) file else null
        } catch (_: Exception) {
            null
        } finally {
            partial.delete()
        }
    }

    private fun circle(source: Bitmap, size: Int): Bitmap {
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val scale = size / minOf(source.width, source.height).toFloat()
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((size - source.width * scale) / 2f, (size - source.height * scale) / 2f)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                .apply { setLocalMatrix(matrix) }
        }
        Canvas(out).drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return out
    }

    private fun initials(target: DirectShareShortcuts.Target, size: Int): Bitmap {
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = PALETTE[Math.floorMod(target.conversationId.hashCode(), PALETTE.size)]
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, fill)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = size * 0.4f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val y = size / 2f - (text.descent() + text.ascent()) / 2f
        canvas.drawText(letters(target.name), size / 2f, y, text)
        return out
    }

    /** First character of the first two words, whole code points only. */
    private fun letters(name: String): String {
        val words = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.take(2)
        if (words.isEmpty()) return "?"
        return words.joinToString("") {
            it.substring(0, Character.charCount(it.codePointAt(0)))
        }.uppercase()
    }

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256").digest(value.toByteArray())
            .joinToString("") { "%02x".format(it) }
}
