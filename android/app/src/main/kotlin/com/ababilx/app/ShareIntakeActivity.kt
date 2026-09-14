package com.ababilx.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Share-sheet trampoline.
 *
 * An exported FlutterActivity with launchMode=singleTop is only reused when it
 * is already at the top of the task Android selected. A share starts from the
 * source app's task, so targeting MainActivity directly can create a second
 * FlutterEngine beside the live-call engine. Forwarding with NEW_TASK brings
 * AbabilX's existing task forward and SINGLE_TOP delivers the payload through
 * MainActivity.onNewIntent instead.
 */
class ShareIntakeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forward(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        forward(intent)
    }

    private fun forward(source: Intent?) {
        if (source == null) {
            finish()
            return
        }
        val grantFlags = source.flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        // The running task was launched through whichever icon alias is
        // currently enabled, so use that launch component as the task key.
        // Pointing NEW_TASK straight at MainActivity does not match an alias-
        // based base intent reliably and can still create a second task.
        val launchComponent = packageManager.getLaunchIntentForPackage(packageName)?.component
        if (launchComponent == null) {
            finish()
            return
        }
        val target = Intent(source).apply {
            component = launchComponent
            flags = grantFlags
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(target)
        finish()
    }
}
