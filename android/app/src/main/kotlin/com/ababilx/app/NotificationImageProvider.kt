package com.ababilx.app

import androidx.core.content.FileProvider

/**
 * Serves the photo of a chat notification to SystemUI.
 *
 * Its own subclass because a manifest may declare androidx's FileProvider only
 * once, and the media-send one must keep sharing nothing but its scratch dir.
 * Not exported: Android 9+ grants SystemUI read access to the URIs inside a
 * posted MessagingStyle notification on the app's behalf, which is exactly
 * the reach this needs and no more.
 */
class NotificationImageProvider : FileProvider()
