package com.ababilx.app.mediasend.camera

/** The zoom arithmetic, apart from CameraX so it can be tested on its own. */
object ZoomMath {

    /**
     * Where a drag along the held capture button takes the lens. [linear] is
     * -1..1: positive zooms in from [base] toward [max], negative out toward
     * [min]. It runs from where the drag started rather than from 1x, so
     * picking the drag up never jumps the lens — Signal's rule. The base is
     * clamped too: one the lens can no longer reach would pin the whole drag
     * to one end.
     */
    fun dragTarget(base: Float, linear: Float, min: Float, max: Float): Float {
        val from = base.coerceIn(min, max)
        val amount = linear.coerceIn(-1f, 1f)
        val target = if (amount >= 0f) from + (max - from) * amount else from + (from - min) * amount
        return target.coerceIn(min, max)
    }
}
