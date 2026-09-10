package com.ababilx.app

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager

/** The window half of [CallLockScreen]: the over-the-keyguard flag and the cover. */
class CallLockWindow(private val activity: Activity) {
    private var view: View? = null

    /** Signal's pair: shown over the keyguard, and waking the screen to do it. */
    @Suppress("DEPRECATION")
    fun setOverLock(on: Boolean) {
        if (Build.VERSION.SDK_INT >= 27) {
            activity.setShowWhenLocked(on)
            activity.setTurnScreenOn(on)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) activity.window.addFlags(flags) else activity.window.clearFlags(flags)
        }
    }

    /**
     * An opaque view over the FlutterView. Black, like the call screen it
     * stands in for; clickable, so nothing underneath can be pressed blind.
     */
    fun cover(on: Boolean) {
        if (!on) {
            view?.let { (it.parent as? ViewGroup)?.removeView(it) }
            view = null
            return
        }
        if (view != null) return
        view = View(activity).apply {
            setBackgroundColor(Color.BLACK)
            isClickable = true
            isFocusable = true
            activity.addContentView(this, ViewGroup.LayoutParams(-1, -1))
        }
    }
}
