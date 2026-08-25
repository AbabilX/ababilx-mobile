# Chat notifications (Android)

> Reworked 2026-08-25: DM pushes showed "🔒 Encrypted message" forever, and no
> notification could be replied to. Read this before touching `chat/`,
> `chat_push_*`, `local_notifications.dart`, or the push payload on the server.

## Why a DM push used to say "🔒 Encrypted message"

DM bodies are E2EE: the server stores ciphertext and **cannot** render a
preview. The only device that can is the recipient's, in its FCM background
isolate, which needs the push to arrive **data-only** — a `notification` block
makes Android draw the tray entry itself and never wake Dart.

The server sends that shape to **every Android device** for an encrypted DM
(`services/notify/fcm_chat_message.go` → `DataOnlyChatPush`, mirrored in
`ababilx-notification/internal/fcm/chat_message.go`). `DeviceRepository.pushCaps`
had been emptied after an earlier attempt showed *no* notification at all, so
every DM fell back to the server-rendered placeholder. Both halves are fixed:

**The tray entry is posted before the decrypt, then rewritten in place.**
`ChatNotificationPresenter.show` posts the placeholder line first and re-posts
the same notification id with the real text once `decryptChatPushBody` returns.
A slow vault, no network, or a background isolate killed mid-flight now costs
the *preview*, never the notification. Server kill switch if it ever regresses:
`CHAT_E2EE_PUSH_DECRYPT=off`.

**One shape per platform — the `e2ee_push` capability no longer gates it.**
Gating on the capability meant a phone with a stale `device_tokens` row (a
reinstall mints a new FCM token; the old row lingers and keeps delivering) was
sent *both* shapes and showed every DM **twice**: the system drew
"🔒 Encrypted message" from the row without the cap while the app drew the
decrypted entry from the row with it. The capability is still registered, for
diagnostics only. Cost of the trade: an Android build too old to decrypt shows
nothing for DMs until it is updated. Duplicate *delivery* is now harmless —
both copies upsert the same `message_id` into the same conversation thread.

## Shape of a chat notification

One entry **per conversation**, not per message (`chatNotificationId`), styled
as an Android MessagingStyle thread — sender as a `Person`, messages stacked,
the user's own replies inline. MessagingStyle needs the whole visible thread on
every post, so the lines live in `ChatNotificationStore`, backed by
`SharedPreferencesAsync` because the app, the FCM isolate and the
notification-action isolate all write to it and none of them share memory.

`alertOnce` is the buzz control: a new message posts with `onlyAlertOnce:
false`, every rewrite (decrypted text, sent reply) with `true`. One buzz per
message.

The thread is cleared when the conversation is read — on notification tap, on
Mark read, and from `markConversationRead` in the chat provider.

## Reply from the notification

`Reply` carries a `RemoteInput`; `Mark read` is a plain action.
`chatNotificationBackgroundAction` (top-level, `@pragma('vm:entry-point')`) runs
them in whatever isolate Android hands them to, and
`handleChatNotificationAction` is shared with the main isolate's tap callback.

A reply is sealed exactly as the composer seals one
(`vault.encryptExisting` → `sendMessage` with an empty `body`), so notification
replies are as end-to-end encrypted as any other message. If the vault cannot
be unlocked offline the reply **fails** rather than silently sending plaintext,
and the text comes back as a "Reply not sent" notification so the user still
has it.

**`AndroidManifest.xml` must declare
`com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver`.** The plugin
does not declare it; without it the buttons render and do nothing.

## Traps

- `LocalNotifications` is a per-isolate singleton on purpose. The native plugin
  is a singleton too, so a second Dart instance calling `initialize` replaces
  the tap callback the app wired at startup — that is how notification taps
  stop navigating.
- Only pushes that arrive **data-only** reach the background isolate. Channel
  and mention pushes still carry a notification block, so in the background
  Android draws them and their entry has no reply button; in the foreground the
  app draws them itself and they do. Making those rich in the background needs
  a server-side data-only shape for them too.
- `sender_name` and `body` are sent in the data map by the server
  (`services/chat/notify_push_payload.go`) for exactly this reason. Older
  servers only put the sender in the title, which `chatSenderName` still
  parses.
- The background isolate must never throw: an uncaught error there takes the
  process down, so every step is best-effort.

## Verifying

`flutter test test/features/notifications/` covers the store, the thread
rewrite, id stability and the sender fallbacks. The rest needs a device:

```bash
adb logcat -s flutter:V | grep -i "\[fcm\]"
```

Send a DM with the app backgrounded, then killed; check the entry shows the
text, reply from the shade without opening the app, and confirm the message
appears in the conversation.
