package com.ababilx.app.backup

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * `com.ababilx.app/local_backup`: the folder picker, the file picker, and the
 * copies in and out of the picked folder. Dart owns the format and the
 * cryptography; this side only moves sealed bytes and never sees a key.
 *
 * Every call answers exactly once. A picker cancelled answers null; a second
 * picker while one is open answers "busy" as an error, never a hang.
 */
class LocalBackupChannel(private val activity: Activity) {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFolder" -> pick(result, REQUEST_FOLDER) {
                        Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(PERSIST_FLAGS).also {
                            // Open in Documents: any file type may live there,
                            // unlike Recordings, Music or Pictures.
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                it.putExtra(DocumentsContract.EXTRA_INITIAL_URI, DOCUMENTS)
                            }
                        }
                    }
                    "pickFile" -> pick(result, REQUEST_FILE) {
                        Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*")
                    }
                    else -> background(result, call.method) { handle(call) }
                }
            }
    }

    private fun handle(call: MethodCall): Any? {
        val context = activity.applicationContext
        return when (call.method) {
            "folderStatus" -> tree(call).let {
                mapOf(
                    "access" to BackupFolder.hasAccess(context, it),
                    "label" to BackupFolder.label(context, it),
                )
            }
            "listBackups" -> BackupFolder.list(context, tree(call)).map { it.toMap() }
            "writeBackup" -> BackupFolder.write(
                context,
                tree(call),
                File(required(call, "source")),
                required(call, "name"),
                required(call, "tag"),
                call.argument<Int>("keep") ?: 2,
            ).toMap()
            "copyToCache" -> BackupFolder.copyToCache(
                context,
                Uri.parse(required(call, "uri")),
                File(required(call, "dest")),
            )
            "releaseFolder" -> {
                runCatching {
                    context.contentResolver.releasePersistableUriPermission(tree(call), RW_FLAGS)
                }
                null
            }
            else -> throw UnsupportedOperationException(call.method)
        }
    }

    /** The picker's answer. True when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_FOLDER && requestCode != REQUEST_FILE) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        val context = activity.applicationContext
        background(result, "pick") {
            if (requestCode == REQUEST_FOLDER) {
                // Held across restarts; without it the daily run could not write.
                context.contentResolver.takePersistableUriPermission(uri, RW_FLAGS)
                mapOf(
                    "uri" to uri.toString(),
                    "label" to BackupFolder.label(context, uri),
                    "writable" to BackupFolder.canWrite(context, uri),
                )
            } else {
                BackupFolder.describe(context, uri)
            }
        }
        return true
    }

    private fun pick(result: MethodChannel.Result, request: Int, intent: () -> Intent) {
        if (pending != null) {
            result.error("busy", "a picker is already open", null)
            return
        }
        pending = result
        try {
            activity.startActivityForResult(intent(), request)
        } catch (error: Exception) {
            pending = null
            result.error("unavailable", error.javaClass.simpleName, null)
        }
    }

    private fun <T> background(result: MethodChannel.Result, step: String, operation: () -> T) {
        io.execute {
            try {
                val value = operation()
                main.post { result.success(value) }
            } catch (error: Throwable) {
                // Logged on this phone only; it names the folder, never content.
                Log.w(TAG, "$step failed", error)
                val code = if (error is BackupFolder.FolderRefusedException) {
                    "folder_refused"
                } else {
                    "local_backup_failed"
                }
                main.post { result.error(code, error.javaClass.simpleName, null) }
            }
        }
    }

    private fun tree(call: MethodCall): Uri = Uri.parse(required(call, "uri"))

    private fun required(call: MethodCall, key: String): String =
        requireNotNull(call.argument<String>(key)).also { require(it.isNotEmpty()) }

    private companion object {
        const val CHANNEL = "com.ababilx.app/local_backup"
        const val TAG = "LocalBackup"
        val DOCUMENTS: Uri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:Documents",
        )
        const val REQUEST_FOLDER = 0xB0A1
        const val REQUEST_FILE = 0xB0A2
        const val RW_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        const val PERSIST_FLAGS = RW_FLAGS or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
    }
}
