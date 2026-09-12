package com.ababilx.app

import android.os.Bundle
import android.telecom.Connection
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hiennv.flutter_callkit_incoming.CallkitCallLifecycle as Calls
import com.hiennv.flutter_callkit_incoming.CallkitConnection
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/** Real Android Connection objects; no mocked disconnect or audio APIs. */
@RunWith(AndroidJUnit4::class)
class CallkitLifecycleTest {
    private fun onMain(test: () -> Unit) =
        InstrumentationRegistry.getInstrumentation().runOnMainSync(test)

    private fun id() = UUID.randomUUID().toString()

    private fun ringing(id: String) = CallkitConnection(id, Bundle()).apply { setRinging() }

    @Test fun duplicatePresentationsReserveOnlyOneOwner() {
        val id = id()
        val start = CountDownLatch(1)
        val admitted = AtomicInteger()
        val workers = (1..16).map {
            thread {
                start.await()
                if (Calls.begin(id)) admitted.incrementAndGet()
            }
        }
        start.countDown()
        workers.forEach { it.join() }
        assertEquals(1, admitted.get())
        onMain { Calls.end(id) }
    }

    @Test fun hiddenRingingSurfaceCanReturnWithoutAnotherConnection() = onMain {
        val id = id()
        assertTrue(Calls.canPresent(id))
        assertTrue(Calls.begin(id))
        val connection = ringing(id)
        Calls.attach(id, connection)
        assertTrue(Calls.canPresent(id))
        assertFalse(Calls.begin(id))
        Calls.accept(id)
        assertFalse(Calls.canPresent(id))
        Calls.end(id)
        assertFalse(Calls.canPresent(id))
    }

    @Test fun duplicateConnectionNeverReplacesOwner() = onMain {
        val id = id()
        assertTrue(Calls.begin(id))
        val first = ringing(id)
        Calls.attach(id, first)
        val duplicate = ringing(id)
        Calls.attach(id, duplicate)
        assertSame(first, Calls.find(id))
        assertEquals(Connection.STATE_DISCONNECTED, duplicate.state)
        Calls.accept(id)
        assertEquals(Connection.STATE_ACTIVE, first.state)
        Calls.end(id)
        assertEquals(Connection.STATE_DISCONNECTED, first.state)
        assertNull(Calls.find(id))
    }

    @Test fun hangupBeforeTelecomCallbackRejectsLateConnection() = onMain {
        val id = id()
        assertTrue(Calls.begin(id))
        Calls.end(id)
        val late = ringing(id)
        Calls.attach(id, late)
        assertEquals(Connection.STATE_DISCONNECTED, late.state)
        assertNull(Calls.find(id))
        assertFalse(Calls.begin(id))
    }

    @Test fun answerBeforeTelecomCallbackActivatesWhenAttached() = onMain {
        val id = id()
        assertTrue(Calls.begin(id))
        Calls.accept(id)
        val late = ringing(id)
        Calls.attach(id, late)
        assertEquals(Connection.STATE_ACTIVE, late.state)
        Calls.end(id)
        assertEquals(Connection.STATE_DISCONNECTED, late.state)
    }

    @Test fun hangupWinsOverQueuedAndRepeatedAnswer() = onMain {
        val id = id()
        assertTrue(Calls.begin(id))
        Calls.accept(id)
        Calls.end(id)
        Calls.accept(id)
        val late = ringing(id)
        Calls.attach(id, late)
        Calls.end(id)
        assertEquals(Connection.STATE_DISCONNECTED, late.state)
        assertNull(Calls.find(id))
    }

    @Test fun endAllIncludesPendingCallsWithoutNotificationRecords() = onMain {
        val pending = id()
        val active = id()
        assertTrue(Calls.begin(pending))
        assertTrue(Calls.begin(active))
        val connected = ringing(active)
        Calls.attach(active, connected)
        Calls.accept(active)
        Calls.endAll()
        val late = ringing(pending)
        Calls.attach(pending, late)
        assertEquals(Connection.STATE_DISCONNECTED, connected.state)
        assertEquals(Connection.STATE_DISCONNECTED, late.state)
        assertEquals(0, Calls.activeCount())
    }
}
