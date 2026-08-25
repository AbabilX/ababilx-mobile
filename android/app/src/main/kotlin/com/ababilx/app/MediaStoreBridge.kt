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
 * Copies a private file into a public MediaStore collection — Pictures,
 * Movies or Downloads, under [subfolder]. Uses MediaStore on API 29+ (no
 * permission needed) and a direct file write below that (requires
 * WRITE_EXTERNAL_STORAGE, maxSdkVersion 28 in the manifest).
 *
 * [deleteSource] defaults to true for the local-share receive path, which has
 * no other copy. Chat attachments pass false: the canonical bytes live in the
 * app sandbox and are what playback reads, and the path returned from here is
 * not readable back on API 29+ under scoped storage — so moving instead of
 * copying would leave the app with no usable file at all.
 *
 * Returns the resulting absolute path, or null on failure.
 */
object MediaStoreBridge {
    fun saveToDownloads(
        context: Context,
        sourcePath: String,
        fileName: String,
        subfolder: String,
        mimeType: String?,
        collection: String = "downloads",
        deleteSource: Boolean = true,
    ): String? {
        val source = File(sourcePath)
        if (!source.exists()) return null

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveViaMediaStore(context, source, fileName, subfolder, mimeType, collection)
            } else {
                saveLegacy(source, fileName, subfolder, collection)
            }
        } catch (e: Exception) {
            null
        } finally {
            if (deleteSource) source.delete()
        }
    }

    private fun baseDirFor(collection: String): String = when (collection) {
        "images" -> Environment.DIRECTORY_PICTURES
        "video" -> Environment.DIRECTORY_MOVIES
        else -> Environment.DIRECTORY_DOWNLOADS
    }

    private fun collectionUriFor(collection: String): Uri = when (collection) {
        "images" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        else -> MediaStore.Downloads.EXTERNAL_CONTENT_URI
    }

    private fun saveViaMediaStore(
        context: Context,
        source: File,
        fileName: String,
        subfolder: String,
        mimeType: String?,
        collection: String,
    ): String? {
        val resolver = context.contentResolver
        val baseDir = baseDirFor(collection)
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType ?: "application/octet-stream")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "$baseDir/$subfolder")
        }
        val uri = resolver.insert(collectionUriFor(collection), values) ?: return null

        val copied = resolver.openOutputStream(uri)?.use { out ->
            FileInputStream(source).use { input -> input.copyTo(out) }
            true
        } ?: false
        if (!copied) return null

        return resolveSavedPath(resolver, uri, subfolder, baseDir)
    }

    private fun resolveSavedPath(resolver: ContentResolver, uri: Uri, subfolder: String, baseDir: String): String? {
        val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
        resolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val savedName = cursor.getString(0)
                val rootDir = "${Environment.getExternalStorageDirectory()}/$baseDir"
                return "$rootDir/$subfolder/$savedName"
            }
        }
        return uri.toString()
    }

    private fun saveLegacy(source: File, fileName: String, subfolder: String, collection: String): String {
        val baseDir = baseDirFor(collection)
        val dir = File(Environment.getExternalStoragePublicDirectory(baseDir), subfolder)
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
