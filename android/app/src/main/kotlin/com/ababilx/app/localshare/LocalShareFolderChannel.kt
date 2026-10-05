package com.ababilx.app.localshare

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `com.ababilx.app/local_share_folder`: lets the user send a whole folder.
 *
 * A folder path from an ordinary file picker cannot be listed on Android 11+
 * without all-files access, which this app does not ask for. The system
 * folder picker grants one tree instead; [LocalShareFolderWalk] reads it.
 * The grant is not persisted — it is needed for one copy and then dropped.
 *
 * `pick` answers exactly once: the folder's name and files, or null when the
 * picker was cancelled, the folder is empty, or another pick is still open.
 */
class LocalShareFolderChannel(private val activity: Activity) {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supported" -> result.success(true)
                    "pick" -> pick(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) return result.success(null)
        pending = result
        try {
            activity.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                REQUEST_FOLDER,
            )
        } catch (e: Exception) {
            Log.w(TAG, "no folder picker: $e")
            pending = null
            result.success(null)
        }
    }

    /** True when the result was this channel's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_FOLDER) return false
        val result = pending ?: return true
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        val context = activity.applicationContext
        io.execute {
            val answer = runCatching {
                val files = LocalShareFolderWalk.copy(context, tree)
                if (files.isEmpty()) {
                    null
                } else {
                    mapOf(
                        "name" to LocalShareFolderWalk.name(context, tree),
                        "files" to files.map { it.toMap() },
                    )
                }
            }.onFailure { Log.w(TAG, "folder copy failed: $it") }.getOrNull()
            main.post { result.success(answer) }
        }
        return true
    }

    private companion object {
        const val CHANNEL = "com.ababilx.app/local_share_folder"
        const val TAG = "LocalShare"
        const val REQUEST_FOLDER = 41208
    }
}
