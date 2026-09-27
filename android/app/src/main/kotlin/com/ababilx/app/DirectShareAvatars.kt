package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.graphics.drawable.IconCompat

/**
 * The round picture on a Direct Share target. The system draws the AbabilX
 * badge over its corner itself.
 *
 * A circle bitmap at the adaptive icon's inner size, as Signal's
 * `getIconCompatForShortcut` does: the share sheet draws it as-is, so the
 * transparent corners are what make it round. Pictures come through Coil
 * ([DirectShareImages]); a chat with none, or one that will not load, gets
 * initials.
 */
object DirectShareAvatars {

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
    fun prune(context: Context, urls: List<String>) = DirectShareImages.prune(context, urls)

    private fun photo(context: Context, url: String, size: Int): Bitmap? =
        DirectShareImages.load(context, url, size)?.let { circle(it, size) }

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
}
