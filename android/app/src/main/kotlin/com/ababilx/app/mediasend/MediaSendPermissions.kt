package com.ababilx.app.mediasend

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build

/**
 * What "can we read the library" means per Android version.
 *
 * Android 14's *Selected photos* grant counts: the query then returns only the
 * photos the user picked, which is a smaller grid rather than a broken one —
 * so `any`, never `all`.
 */
object MediaSendPermissions {

    const val REQUEST_CODE = 4103

    fun required(): List<String> = when {
        Build.VERSION.SDK_INT >= 34 -> listOf(
            "android.permission.READ_MEDIA_IMAGES",
            "android.permission.READ_MEDIA_VIDEO",
            "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
        )
        Build.VERSION.SDK_INT >= 33 -> listOf(
            "android.permission.READ_MEDIA_IMAGES",
            "android.permission.READ_MEDIA_VIDEO",
        )
        else -> listOf("android.permission.READ_EXTERNAL_STORAGE")
    }

    fun granted(activity: Activity): Boolean = required().any {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun request(activity: Activity) {
        activity.requestPermissions(required().toTypedArray(), REQUEST_CODE)
    }
}
