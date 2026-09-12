package com.ababilx.app

import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.telecom.Connection
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hiennv.flutter_callkit_incoming.CallkitCallLifecycle as Calls
import com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver as Receiver
import com.hiennv.flutter_callkit_incoming.Data
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/** Emulator-only: exercises the real ConnectionService and inspects Telecom.
 * Does not place a SIM call or establish WebRTC media.
 */
@RunWith(AndroidJUnit4::class)
class CallkitTelecomTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private fun onMain(block: () -> Unit) = instrumentation.runOnMainSync(block)

    private fun shell(command: String): String =
        ParcelFileDescriptor.AutoCloseInputStream(instrumentation.uiAutomation.executeShellCommand(command))
            .bufferedReader().use { it.readText() }

    private fun telecomCalls(): String = shell("dumpsys telecom")
        .substringAfter("  mCalls:", "missing mCalls section")
        .substringBefore("  mCallAudioManager:").trim()

    private fun eventually(label: String, check: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 10_000
        while (SystemClock.elapsedRealtime() < deadline) {
            if (check()) return
            SystemClock.sleep(100)
        }
        fail(label)
    }

    private val result = object : MethodChannel.Result {
        override fun success(result: Any?) {}
        override fun error(code: String, message: String?, details: Any?) = fail("$code: $message")
        override fun notImplemented() = fail("Plugin method missing")
    }

    @Test fun duplicateIncomingAnswerEndLeavesTelecomIdleAcrossFiveSessions() {
        assumeTrue(Build.FINGERPRINT.contains("generic") || Build.MODEL.contains("sdk"))
        assumeTrue(Build.VERSION.SDK_INT >= 26)
        assertEquals("Run on an idle emulator", "", telecomCalls())
        lateinit var engine: FlutterEngine
        onMain { engine = FlutterEngine(context) }
        try {
            repeat(5) {
                val id = UUID.randomUUID().toString()
                val data = Data(hashMapOf<String, Any?>(
                    "id" to id, "nameCaller" to "Telecom regression", "handle" to "Test",
                    "type" to 0, "duration" to 60_000,
                    "android" to hashMapOf("isFullScreen" to false, "ringtonePath" to "silent_ring")
                ))
                onMain {
                    // Both presentations execute before the async service callback,
                    // reproducing the original check-then-register race deterministically.
                    val receiver = Receiver()
                    val intent = Receiver.getIntentIncoming(context, data.toBundle())
                    receiver.onReceive(context, intent)
                    receiver.onReceive(context, intent)
                }
                eventually("Telecom did not attach incoming call") { Calls.find(id) != null }
                eventually("Expected exactly one Telecom call") {
                    Regex("(?m)^\\s*\\[Call id=").findAll(telecomCalls()).count() == 1
                }
                onMain {
                    FlutterCallkitIncomingPlugin.getInstance()!!.onMethodCall(
                        MethodCall("callConnected", hashMapOf("id" to id)), result)
                }
                eventually("In-app answer did not activate Telecom") {
                    Calls.find(id)?.state == Connection.STATE_ACTIVE
                }
                onMain {
                    FlutterCallkitIncomingPlugin.getInstance()!!.onMethodCall(
                        MethodCall("endCall", hashMapOf("id" to id)), result)
                }
                eventually("Orphan Telecom call after end") { telecomCalls().isEmpty() }
                eventually("Telecom audio mode not released") {
                    Regex("Actual mode[ :=]+MODE_NORMAL").containsMatchIn(shell("dumpsys audio"))
                }
                assertEquals(0, Calls.activeCount())
            }
        } finally {
            onMain {
                FlutterCallkitIncomingPlugin.getInstance()?.onMethodCall(
                    MethodCall("endAllCalls", null), result)
                engine.destroy()
            }
        }
    }
}
