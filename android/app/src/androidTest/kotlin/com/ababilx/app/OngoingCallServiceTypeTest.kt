package com.ababilx.app

import android.content.pm.ServiceInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OngoingCallServiceTypeTest {
    @Test fun listenOnlyCallStillUsesPhoneCallType() {
        val type = OngoingCallService.serviceTypeFor(
            hasMicrophone = false,
            screenSharing = false,
        )
        assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL, type)
    }

    @Test fun grantedCapabilitiesAreAddedWithoutDroppingPhoneCall() {
        val type = OngoingCallService.serviceTypeFor(
            hasMicrophone = true,
            screenSharing = true,
        )
        assertTrue(type and ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL != 0)
        assertTrue(type and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE != 0)
        assertTrue(type and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION != 0)
    }
}
