package com.hiennv.flutter_callkit_incoming

import android.os.Build
import android.telecom.Connection
import android.telecom.DisconnectCause
import androidx.annotation.RequiresApi

/**
 * Process-wide call ownership, shared by UI and background Flutter engines.
 * Reserve BEFORE requesting Telecom, then attach its asynchronous result.
 * Like Signal's call controller, an early Answer/End survives late approval.
 * Call ids are session UUIDs; a terminated session cannot be presented again.
 */
@RequiresApi(Build.VERSION_CODES.M)
object CallkitCallLifecycle {
    private class PendingCall(var connection: CallkitConnection? = null, var accepted: Boolean = false)

    private val calls = mutableMapOf<String, PendingCall>()
    private val ended = linkedSetOf<String>()

    @Synchronized
    fun begin(id: String): Boolean {
        if (id.isEmpty() || id in ended || id in calls) return false
        calls[id] = PendingCall()
        return true
    }

    @Synchronized
    fun canPresent(id: String): Boolean = id.isNotEmpty() && id !in ended &&
        calls[id]?.accepted != true && calls[id]?.connection?.state != Connection.STATE_ACTIVE

    @Synchronized
    fun attach(id: String, connection: CallkitConnection) {
        val pending = calls[id]
        if (pending == null || pending.connection != null || id in ended) {
            // Never overwrite an owner. Close this late/duplicate object only.
            connection.finishWithCause(DisconnectCause.CANCELED)
            return
        }
        pending.connection = connection
        if (pending.accepted) connection.markAccepted()
    }

    @Synchronized
    fun accept(id: String) {
        val pending = calls[id] ?: return
        pending.accepted = true
        pending.connection?.markAccepted()
    }

    @Synchronized
    fun end(id: String, cause: Int = DisconnectCause.LOCAL) {
        if (id.isEmpty()) return
        val connection = calls.remove(id)?.connection
        rememberEnded(id)
        connection?.finishWithCause(cause)
    }

    @Synchronized
    fun finished(id: String, connection: CallkitConnection) {
        if (calls[id]?.connection === connection) {
            calls.remove(id)
            rememberEnded(id)
        }
    }

    @Synchronized
    fun endAll() {
        calls.keys.toList().forEach { end(it) }
    }

    @Synchronized
    fun find(id: String): CallkitConnection? = calls[id]?.connection

    @Synchronized
    fun activeCount(): Int = calls.values.count { it.connection != null }

    private fun rememberEnded(id: String) {
        ended.add(id)
        // Bounded replay protection; live/pending owners are never evicted.
        while (ended.size > 256) ended.remove(ended.first())
    }
}
