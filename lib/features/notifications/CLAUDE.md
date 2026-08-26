# Chat notifications (Android)

> **Settled 2026-08-26 — verified working on device. Do not rework.**
> DM pushes showed "🔒 Encrypted message" forever, then showed every message
> **twice**. Both are fixed and confirmed in production. The duplicate took four
> rounds because three plausible causes were fixed blind before the real one was
> proven; the section "How the duplicate was actually found" below records the
> method, and it is the part to reuse — not the guesses.
>
> Read this before touching `chat/`, `chat_push_*`, `local_notifications.dart`,
> or the push shape in **either** Go sender.

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
the *preview*, never the notification.

**One shape per platform — the `e2ee_push` capability no longer gates it.**
Gating on the capability meant a phone with a stale `device_tokens` row (a
reinstall mints a new FCM token; the old row lingers and keeps delivering) was
sent *both* shapes and showed every DM **twice**: the system drew
"🔒 Encrypted message" from the row without the cap while the app drew the
decrypted entry from the row with it. The capability is still registered, for
diagnostics only. Cost of the trade: an Android build too old to decrypt shows
nothing for DMs until it is updated. Duplicate *delivery* is now harmless —
both copies upsert the same `message_id` into the same conversation thread.

**The duplicate was `CHAT_E2EE_PUSH_DECRYPT` set to a disabling value in the
`ababilx-notification` deployment.** It forced every encrypted DM back to a
notification block; the data map still rode along, so the OS drew the
"🔒 Encrypted message" placeholder *and* the app decrypted and drew the real
text. Backgrounded that is two tray entries, foregrounded one — because the OS
only draws a notification block while the app is backgrounded
([Firebase: about FCM messages](https://firebase.google.com/docs/cloud-messaging/concept-options)).
That asymmetry is the fingerprint: **1 foreground / 2 background = one push
carrying both shapes**, never two pushes.

**The switch is gone.** No environment variable decides the push shape any
more, in either service — it is `encryptedChatPush(data) &&
clientRendersChatPush(platform)` and nothing else. A config nobody can see
outranking committed code is what made this take four rounds; tests in both
services now assert that setting `CHAT_E2EE_PUSH_DECRYPT` cannot bring it back.

**The client draws its own entry — every platform.** Both senders picked the shape with `isAndroid(platform)`, so a
`device_tokens` row whose platform was not literally `android` — blank,
defaulted, written by a build that no longer exists — got the notification
shape, which the OS draws itself, on top of the entry the app drew from the
data-only copy. Same message, two tray lines, one of them the "🔒 Encrypted
message" placeholder.

The predicate is now `clientRendersChatPush(platform)` in both senders, and it
defaults to **true**: an unrecognised platform string can no longer bring the
duplicate back. This is the global rule, not an Android carve-out — the server
holds only ciphertext, so no server-rendered entry can ever say more than the
placeholder on any platform. Signal is the reference: `examples/Signal-Server`
→ `push/FcmSender.java` builds every message as token + `AndroidConfig` +
`putData` and attaches no notification block anywhere.

Apple is the single exception still in the switch, and it is a missing target
rather than a decision: `ios/Runner.xcodeproj` has no
`UNNotificationServiceExtension`, so a data-only push would arrive silent and
show nothing at all. iOS therefore keeps the placeholder notification. Ship that
extension and the case deletes, leaving the rule uniform. Web/desktop already
fall on the default side — neither registers an FCM token today, and when they
do, an `onBackgroundMessage` service-worker handler is all they need.

The fix is server-side only: nothing about the phone, its registration or its
session changes, so it takes effect on the next message with no reinstall,
re-login or token refresh.

**One row per handset, enforced at fan-out.** `device_tokens` is keyed by
`fcm_token`, and a token is not a device: it rotates on reinstall and leaves the
old row live. Registration now sweeps this user's rows for the same `device_id`
and rows with none at all (`db.UpsertDeviceTokenWithCaps`), and the fan-out
query collapses rows sharing a `device_id` to the newest
(`GetDeviceTokensWithPlatform`, mirrored in `ababilx-notification`
`GetDevicesByUserID`). Platform is *not* part of the sweep predicate — a stale
row not recognised as Android is sent a notification block, which Android draws
itself on top of the entry the app draws from the data-only copy, which is the
duplicate this whole section exists to prevent.

**Both senders must be deployed together.** `ababilx-server` publishes to NATS
and returns; `ababilx-notification` is what actually calls FCM. Shipping the
server alone leaves the old shape logic running.

**Foreground vs background tells you which half is wrong.** A push carrying a
notification block is drawn by the OS *only while the app is backgrounded* — a
foreground app is handed the message and the OS draws nothing. So:

| symptom | meaning |
|---|---|
| 1 entry foreground, **2 backgrounded** | one push carrying *both* a notification block and data. Sender is still building the notification shape. |
| 2 entries in both | two pushes — duplicate `device_tokens` rows, or JetStream redelivery. |

Both senders log the decision per device, with the reason: `[fcm] shape token=… platform=… shape=data-only|notification reason=ok|not_encrypted|platform_has_no_decrypt_client`. An encrypted DM that logs `notification` is the bug, and the line prints the `platform` that caused it. No `[fcm] shape` line at all means that process is not the sender — check the other one (`ababilx-server` logs `[push] NATS unavailable` when it takes over). `ababilx-notification` also prints `boot: … build=<commit>`, which answers "is the deployed service actually the code I pushed?"

## How the duplicate was actually found

Three fixes shipped and changed nothing: removing the `push_caps` gate, adding
`device_id` dedup at registration, then dedup at fan-out. All three assumed
*two pushes*. The bug was *one push carrying both shapes*.

What proved it, in order:

1. **The foreground/background asymmetry.** One entry with the app open, two with
   it backgrounded. Android draws a notification block **only** while the app is
   backgrounded ([Firebase: about FCM
   messages](https://firebase.google.com/docs/cloud-messaging/concept-options)),
   so 1-vs-2 can only mean a single message carrying a notification block *and* a
   data map. Two pushes would have shown two entries in both states. This one
   observation eliminated every stale-row theory at once.
2. **Logging the decision, not the outcome.** `[fcm] shape … platform=… shape=…
   reason=…` printed per device, immediately before `Send`. The line read
   `platform="android" shape=notification` with `encrypted=true` — which pinned
   the failure to exactly one term of a three-term `&&`.
3. **Confirming the running binary.** `boot: … build=<commit>` exists because a
   redeploy that silently did not happen is indistinguishable from a fix that did
   not work. It ruled out the "stale deployment" theory and left one cause.

The cause: `CHAT_E2EE_PUSH_DECRYPT` set to a disabling value in the
`ababilx-notification` deployment — config nobody could see outranking committed
code. **The switch is deleted from both services.** Neither file imports `os`
any more, so no environment can influence the shape; tests in both assert that
setting the variable cannot bring the duplicate back.

**Reusable rule:** when a push bug survives a fix, log the *decision* the sender
made and the *build* it made it in, before changing any more logic.

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
