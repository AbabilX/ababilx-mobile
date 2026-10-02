package com.ababilx.app.mediasend.camera

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry

/**
 * The lifecycle CameraX binds to — the camera screen's, not the Activity's.
 *
 * `MediaSendActivity` is a plain Activity, and even if it were a
 * LifecycleOwner its lifecycle would be the wrong one: the flow keeps the
 * camera screen as a `GONE` sibling while the review screen is up, and a
 * camera bound to the Activity would hold the sensor (and its green privacy
 * dot) open behind a screen showing a photo. So the camera is RESUMED exactly
 * while it is on screen AND the Activity is in the foreground, and drops to
 * CREATED — which closes the device — the moment either stops being true.
 */
class CameraLifecycle : LifecycleOwner {

    private val registry = LifecycleRegistry(this).apply {
        currentState = Lifecycle.State.CREATED
    }

    private var shown = false
    private var foreground = true

    override val lifecycle: Lifecycle get() = registry

    /** The camera screen became visible (true) or was replaced (false). */
    fun setShown(value: Boolean) {
        shown = value
        sync()
    }

    /** Mirrors the Activity's onResume / onPause. */
    fun setForeground(value: Boolean) {
        foreground = value
        sync()
    }

    val isActive: Boolean get() = shown && foreground

    /** Final: the Activity is going away and nothing may rebind after this. */
    fun destroy() {
        if (registry.currentState == Lifecycle.State.DESTROYED) return
        registry.currentState = Lifecycle.State.DESTROYED
    }

    private fun sync() {
        if (registry.currentState == Lifecycle.State.DESTROYED) return
        registry.currentState =
            if (isActive) Lifecycle.State.RESUMED else Lifecycle.State.CREATED
    }
}
