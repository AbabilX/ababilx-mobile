package com.ababilx.app

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

/**
 * Copies a private temp file into the public Downloads/[subfolder] collection.
 * Uses MediaStore on API 29+ (no permission needed) and a direct file write
 * below that (requires WRITE_EXTERNAL_STORAGE, maxSdkVersion 28 in the
 * manifest). Deletes [sourcePath] once copied. Returns the resulting
 * absolute path, or null on failure.
 */
object MediaStoreBridge {
    fun saveToDownloads(
        context: Context,
        sourcePath: String,
        fileName: String,
        subfolder: String,
        mimeType: String?,
    ): String? {
        val source = File(sourcePath)
        if (!source.exists()) return null

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveViaMediaStore(context, source, fileName, subfolder, mimeType)
            } else {
                saveLegacy(source, fileName, subfolder)
            }
        } catch (e: Exception) {
            null
        } finally {
            source.delete()
        }
    }

    private fun saveViaMediaStore(
        context: Context,
        source: File,
        fileName: String,
        subfolder: String,
        mimeType: String?,
    ): String? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType ?: "application/octet-stream")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$subfolder")
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null

        val copied = resolver.openOutputStream(uri)?.use { out ->
            FileInputStream(source).use { input -> input.copyTo(out) }
            true
        } ?: false
        if (!copied) return null

        return resolveSavedPath(resolver, uri, subfolder)
    }

    private fun resolveSavedPath(resolver: ContentResolver, uri: Uri, subfolder: String): String? {
        val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
        resolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val savedName = cursor.getString(0)
                val downloadsDir = "${Environment.getExternalStorageDirectory()}/${Environment.DIRECTORY_DOWNLOADS}"
                return "$downloadsDir/$subfolder/$savedName"
            }
        }
        return uri.toString()
    }

    private fun saveLegacy(source: File, fileName: String, subfolder: String): String {
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), subfolder)
        if (!dir.exists()) dir.mkdirs()

        var dest = File(dir, fileName)
        val baseName = dest.nameWithoutExtension
        val ext = dest.extension
        var index = 1
        while (dest.exists()) {
            val suffixed = if (ext.isNotEmpty()) "$baseName ($index).$ext" else "$baseName ($index)"
            dest = File(dir, suffixed)
            index++
        }
        source.copyTo(dest)
        return dest.absolutePath
    }
}
