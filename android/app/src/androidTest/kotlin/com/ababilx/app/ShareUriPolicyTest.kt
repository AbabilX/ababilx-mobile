package com.ababilx.app

import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Real package manager and paths: own providers are resolved as on a phone. */
@RunWith(AndroidJUnit4::class)
class ShareUriPolicyTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val own = context.packageName

    @Test fun ownPrivateFilesAreRefused() {
        val private = Uri.fromFile(File(context.filesDir, "anything.db"))
        assertFalse(ShareUriPolicy.acceptIncoming(context, private))
        assertFalse(ShareUriPolicy.acceptForRead(context, private))
    }

    @Test fun ownProvidersAreRefused() {
        for (authority in listOf(
            "$own.mediasend.fileprovider",
            "$own.notificationimages",
            "$own.ghostblob",
            "0@$own.mediasend.fileprovider",
            "$own.unknown",
        )) {
            val uri = Uri.parse("content://$authority/x/y")
            assertFalse(authority, ShareUriPolicy.acceptIncoming(context, uri))
            assertFalse(authority, ShareUriPolicy.acceptForRead(context, uri))
        }
    }

    @Test fun otherAppsProvidersAreAccepted() {
        val media = Uri.parse("content://media/external/images/media/1")
        assertTrue(ShareUriPolicy.acceptIncoming(context, media))
        assertTrue(ShareUriPolicy.acceptForRead(context, media))
    }

    @Test fun reviewedFilesAreReadableButNeverIncoming() {
        val reviewed = Uri.fromFile(File(File(context.cacheDir, "mediasend"), "1-photo.jpg"))
        assertFalse(ShareUriPolicy.acceptIncoming(context, reviewed))
        assertTrue(ShareUriPolicy.acceptForRead(context, reviewed))
    }

    @Test fun pathsEscapingTheReviewFolderAreRefused() {
        val escaped = Uri.parse("file://${context.cacheDir}/mediasend/../../files/a.db")
        assertFalse(ShareUriPolicy.acceptForRead(context, escaped))
        val sibling = Uri.fromFile(File(context.cacheDir, "mediasend-other/a.jpg"))
        assertFalse(ShareUriPolicy.acceptForRead(context, sibling))
    }

    @Test fun otherSchemesAreRefused() {
        for (raw in listOf("https://example.com/a.jpg", "android.resource://$own/1", "x")) {
            assertFalse(raw, ShareUriPolicy.acceptForRead(context, Uri.parse(raw)))
        }
    }
}
