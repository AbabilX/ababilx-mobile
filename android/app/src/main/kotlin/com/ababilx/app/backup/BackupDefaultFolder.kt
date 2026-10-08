package com.ababilx.app.backup

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.StatFs
import java.io.File

/**
 * Where the automatic backup goes when the person picked no folder.
 *
 * Android 11+: `Documents/AbabilX`, written with plain file paths — an app may
 * create and read its OWN files there with no permission. The folder outlives
 * an uninstall, which the app's own `Android/media/<package>` does not
 * (installd deletes it with the app's data). The price: a reinstalled app is
 * a new owner, so Android hides the old files from it until the person grants
 * the folder once through the system picker.
 *
 * Android 10 and below cannot write to Documents by path without a storage
 * permission, so the app's own external folder is used there.
 */
object BackupDefaultFolder {
    const val FOLDER = "AbabilX"

    fun describe(context: Context): Map<String, Any?> {
        val public = publicFolder()?.takeIf { writable(it) }
        val folder = public ?: privateFolder(context)
        folder.mkdirs()
        return mapOf(
            "path" to folder.absolutePath,
            "free" to free(folder),
            "public" to (public != null),
        )
    }

    private fun publicFolder(): File? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        if (Environment.getExternalStorageState() != Environment.MEDIA_MOUNTED) return null
        val documents =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
        return File(documents, FOLDER)
    }

    private fun privateFolder(context: Context): File {
        @Suppress("DEPRECATION")
        val base = context.externalMediaDirs.firstOrNull { it != null }
            ?: context.getExternalFilesDir(null)
            ?: context.filesDir
        return File(base, "Backups")
    }

    /**
     * A uniquely named probe: after a reinstall an older probe would still be
     * there, invisible to us, and creating the same name again fails.
     */
    private fun writable(folder: File): Boolean = runCatching {
        if (!folder.isDirectory && !folder.mkdirs()) return false
        val probe = File(folder, "check-${System.nanoTime()}.tmp")
        probe.outputStream().use { it.write(0) }
        probe.delete()
        true
    }.getOrDefault(false)

    private fun free(folder: File): Long =
        runCatching { StatFs(folder.absolutePath).availableBytes }.getOrDefault(0L)
}
