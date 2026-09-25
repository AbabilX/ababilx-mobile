package com.ababilx.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.MotionEvent

/**
 * Keeps a cheek off the call screen.
 *
 * [CallScreenLock]'s proximity wake lock asks the system to blank the panel at
 * the ear, and on most phones the system also stops delivering touches while
 * it is dark. Not on every phone: some handsets (virtual / ultrasonic
 * proximity sensors in particular) keep the touchscreen live, or blank it only
 * after the cheek has already landed. There, holding a call to the face
 * pressed Hang up, and taking the phone away again pressed Call in the chat
 * header the app had just returned to — reported as "the call dropped at his
 * ear, and when he took the phone away I got a new call from him".
 *
 * So the app reads the same sensor itself, and while it says NEAR every touch
 * is dropped before Flutter sees it. A gesture already handed to Flutter when
 * the sensor trips is cancelled, so the cheek that just landed cannot finish
 * a tap on the way off. Touches stay blocked for [GRACE_MS] after the sensor
 * goes FAR, because the panel wakes before the ear has fully left it.
 *
 * On a phone whose system already drops touches at the ear nothing changes:
 * the guard only ever blocks what the system was blocking anyway, plus that
 * short grace after the phone comes away.
 *
 * When the call no longer wants the lock (it ended, speaker, a headset) while
 * the phone is still at the ear, the guard keeps running until the sensor
 * reads FAR — the same moment `RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY` gives the
 * screen back — capped at [TAIL_CAP_MS] so a sensor stuck on NEAR cannot lock
 * the app out.
 */
class ProximityTouchGuard(
    context: Context,
    /** Delivers a synthetic cancel straight to the window, past this guard. */
    private val cancelSink: (MotionEvent) -> Unit,
) : SensorEventListener {

    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val sensor: Sensor? =
        runCatching { sensors?.getDefaultSensor(Sensor.TYPE_PROXIMITY) }.getOrNull()
    private val handler = Handler(Looper.getMainLooper())

    private var listening = false
    private var near = false
    private var farAt = 0L

    /** The call has let go; stop once the phone is away from the face. */
    private var tail = false

    /** Latest event of the gesture Flutter is holding, for building its cancel. */
    private var delivered: MotionEvent? = null

    /** Dropping the current gesture until its last finger lifts. */
    private var swallowing = false

    private val stopTail = Runnable { stop() }

    fun start() {
        tail = false
        handler.removeCallbacks(stopTail)
        if (listening) return
        val manager = sensors ?: return
        val proximity = sensor ?: return
        near = false
        farAt = 0L
        listening = runCatching {
            manager.registerListener(this, proximity, SensorManager.SENSOR_DELAY_NORMAL, handler)
        }.getOrDefault(false)
    }

    fun stopWhenClear() {
        if (!listening || tail) return
        if (!near && !inGrace(SystemClock.uptimeMillis())) {
            stop()
            return
        }
        tail = true
        handler.removeCallbacks(stopTail)
        handler.postDelayed(stopTail, if (near) TAIL_CAP_MS else GRACE_MS)
    }

    fun stop() {
        handler.removeCallbacks(stopTail)
        tail = false
        if (listening) runCatching { sensors?.unregisterListener(this) }
        listening = false
        near = false
        forgetDelivered()
    }

    /** Routes one touch event: to [deliver], or nowhere while at the ear. */
    fun dispatch(event: MotionEvent, deliver: (MotionEvent) -> Boolean): Boolean {
        val action = event.actionMasked
        val last = action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL
        if (action == MotionEvent.ACTION_DOWN) {
            forgetDelivered()
            swallowing = blocking(event.eventTime)
        }
        if (swallowing) {
            if (last) swallowing = false
            return true
        }
        val handled = deliver(event)
        if (last || !listening) forgetDelivered() else remember(event)
        return handled
    }

    override fun onSensorChanged(event: SensorEvent) {
        val distance = event.values.firstOrNull() ?: return
        val threshold = minOf(event.sensor.maximumRange, NEAR_THRESHOLD_CM)
        val isNear = distance >= 0f && distance < threshold
        if (isNear == near) return
        near = isNear
        Log.i(TAG, "proximity ${if (isNear) "near" else "far"}")
        if (isNear) {
            cancelDelivered()
            return
        }
        farAt = SystemClock.uptimeMillis()
        if (tail) {
            handler.removeCallbacks(stopTail)
            handler.postDelayed(stopTail, GRACE_MS)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun blocking(now: Long) = listening && (near || inGrace(now))

    private fun inGrace(now: Long) = farAt > 0L && now - farAt < GRACE_MS

    private fun remember(event: MotionEvent) {
        delivered?.recycle()
        delivered = MotionEvent.obtain(event)
    }

    private fun forgetDelivered() {
        delivered?.recycle()
        delivered = null
    }

    /** The sensor tripped mid-gesture: take the gesture back from Flutter. */
    private fun cancelDelivered() {
        val last = delivered ?: return
        delivered = null
        swallowing = true
        val cancel = MotionEvent.obtain(last).apply { action = MotionEvent.ACTION_CANCEL }
        last.recycle()
        runCatching { cancelSink(cancel) }.onFailure { Log.w(TAG, "cancel failed", it) }
        cancel.recycle()
    }

    companion object {
        private const val TAG = "ababilx:call-touch"

        /** AOSP's own cut-off for "near" (`DisplayPowerProximityStateController`). */
        private const val NEAR_THRESHOLD_CM = 5f
        const val GRACE_MS = 600L
        const val TAIL_CAP_MS = 30_000L
    }
}
