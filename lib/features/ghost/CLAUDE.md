# Ghost Chat (mobile)

Added 2026-09-17. Product and server design: root `CLAUDE.md`, "Ghost Chat".
This file is what the phone adds.

```
+ panel chip -> intro sheet -> invite()          GhostSync pushes /ghost
ghost.invite (WS) or ghost_invite (FCM tap+replay) -> /ghost/invite
Join -> accept() -> /ghost (pushReplacement)     Decline -> idle, route pops
flame -> burn()   back -> leave() (asks if there is content)   -> ended -> Close -> idle
```

## Layout

| Dir | Owns |
|---|---|
| `data/` | `GhostApi` (start/accept/finish/heartbeat), `GhostSession` |
| `protocol/` | data-channel frames and file reassembly — pure, tested |
| `webrtc/` | `GhostPeer` (one negotiated channel, inviter offers), `GhostFileSender` (backpressure) |
| `providers/` | `GhostNotifier` split into mixins over `_GhostBase`: signal, link, content, view, end |
| `screens/`, `widgets/` | invite, chat, header with the flame, bubbles, composer, ended view |
| `ghost_sync.dart` | the ONLY thing that navigates Ghost Chat routes; lifecycle; secure window |
| `ghost_push.dart` | `ghost_invite` / `ghost_closed` notifications (foreground + background isolate) |

The key sealing lives with the rest of the key code:
`messages/message_e2ee/message_vault_ghost.dart` (`ghostKeyVersion`,
`sealGhostSignal`, `openGhostSignal`).

## Rules that are easy to break

- **Nothing here may touch the chat store, the outbox, drift, secure storage
  or `AttachmentAdopter`.** The provider holds content in `GhostState.items`
  and nowhere else. A "helpful" cache is the feature failing silently.
- **Mixins, not extensions.** Riverpod's `state` setter is `@protected`; an
  extension on the notifier trips `invalid_use_of_protected_member`. Anything
  one mixin calls on another is declared abstract on `_GhostBase`.
- **Incoming signals wait on `_ready`, never on a nullable future.** The
  inviter's offer can arrive before the accept HTTP response does; awaiting a
  null there dropped the offer and the join hung on "Connecting…".
- **Outgoing signals go through one `_signalsOut` chain.** Sealing is async;
  without the chain an ICE candidate overtakes its offer.
- **Picker copies are deleted by path, and only inside our cache dir**
  (`GhostTempFiles.deletePickerCopy`). Both picker plugins copy the chosen file
  into `getTemporaryDirectory()` and never clean it up. The user's original
  must never be the thing deleted, hence the `startsWith('$cache/')` + no `..`
  check.
- **Backgrounding is not an instant burn.** The system file picker and camera
  pause the app, so `paused` starts a 30 s grace and `resumed` cancels it;
  `detached` leaves immediately. A camera session longer than 30 s burns the
  chat, and that is the accepted edge.
- **The flame asks nothing.** The user asked for "instantly". Back asks,
  because back is pressed by accident far more often than a flame.
- `GhostSecureWindow` calls `com.ababilx.app/secure_window` `setSecure`
  (`android/.../SecureWindowChannel.kt`, `FLAG_SECURE`). Dart sends only
  changes, so the Kotlin side keeps the wanted state in its companion and
  re-applies it when a new Activity attaches. Nothing else sets this flag.
  Android only; the Dart half tolerates a missing native half.

## Photo timer and "allow saving" (2026-09-22)

The sender decides, per photo or file, in the send preview
(`widgets/ghost_send_preview.dart`, shown after every pick; the last choice is
offered again for the rest of the session via `GhostState.lastRules`).

```
file header  "view":"once"|5|10|30   photos only; absent = no timer
             "save":true             absent = view only
{"t":"viewed","id":…}                receiver -> sender: a timed photo is gone
```

- **Timed photo** (`GhostItemRules.timer`): never drawn in the receiver's
  list — "Photo · 5 seconds / Tap to view", no thumbnail (a blur is still a
  copy). The countdown starts on open, in `GhostPhotoViewer`, on a wall-clock
  `Timer` (animations stop in the background). Every way out of the viewer
  calls `viewed()` from `dispose`: the receiver zeroes the bytes, evicts the
  image cache and sends `viewed`; the sender does the same on receipt. Both
  bubbles become "Viewed" / "Opened". A peer's `viewed` can only expire the
  sender's OWN timed photo, so a forged id costs nothing.
- **An unknown `view` value decodes to once**, never to off: a limit we do not
  understand is read as the strictest one. A `view` on a non-photo is dropped.
- **A timed photo cannot be saved** — `GhostItemRules` forces `allowSave`
  false whenever a timer is set, so a forged `"save":true` beside a timer is
  refused on decode, not only in the UI.
- **View only (default)**: the receiver's file may not leave the app.
  Photos open in `GhostPhotoViewer`, PDFs in `GhostPdfViewer`, videos in
  `GhostVideoViewer`; anything else cannot be opened ("Saving is off").
  `GhostItem.mayLeaveApp` is the single test; the sender's own items always
  may.
- **PDFs render natively, never through pdfx.** pdfx's `openData` writes the
  document into `cacheDir` as a plain `.pdf` and never deletes it, and renders
  pages to image files. `GhostPdfDocuments.kt` opens Android's `PdfRenderer`
  over `GhostBlobProvider.readDescriptor` (RAM-backed, seekable, API 26+) and
  returns each page as PNG bytes; the viewer zeroes them on close, the burn
  closes every document. Below API 26 / on iOS a view-only PDF cannot be shown.
- **Video plays from the blob's `content://` uri** (`VideoPlayerController.contentUri`,
  our own non-exported provider); iOS falls back to the ghost temp file.
- **Allowed**: a Save button (file row, photo viewer) and opening in another
  app as before. Save passes the bytes through the ghost temp dir only for the
  MediaStore copy (`providers/ghost_save.dart`), then deletes it.
- **Viewers close themselves** (`watchGhostViewerItem`) when the chat ends or
  the item expires. GhostSync moves routes only on `idle`, which is later.
- **A build from before this ignores both fields**: it shows a timed photo
  inline for good and lets any file open elsewhere. Both phones must update.
- `FLAG_SECURE` already covers the whole session; the honest limit (a camera
  at the screen, a modified client) is unchanged.

## Taken from Signal-Android (`examples/Signal-Android`, AGPL, read-only)

Read for the approach and the platform API, then written fresh here — never
pasted, the same rule the media-send flow follows.

- **Memory blobs** (`BlobProvider`, `PartProvider`): ephemeral bytes are served
  to other apps from RAM, not from a temp file. Ours is `GhostBlobProvider.kt`.
  Signal's `SINGLE_USE_MEMORY` drops a blob on first read; ours holds it for the
  session instead, because a viewer that re-opens on rotation would otherwise
  get an empty file — the burn is what clears it, which is Signal's
  `SINGLE_SESSION_MEMORY` semantics.
- **A seekable descriptor, not a pipe** (`PartProvider.getParcelStreamProxyFor…`,
  `MemoryFileUtil`): `StorageManager.openProxyFileDescriptor` on API 26+. Signal
  falls back to a `MemoryFile` through reflection on older devices; we fall back
  to a pipe, which is honest for images and admits it cannot seek.
- **Single-session cleanup at start** (`BlobProvider.initialize`): the ghost temp
  directory is purged on every launch, so a process killed mid-session leaves
  nothing.
- **Counted screenshot holds** (`TemporaryScreenshotSecurity`): the flag goes up
  on the first hold and down on the last, never on whoever finishes first.
- **Incognito keyboard** (`EditTextExtensions.setIncognitoKeyboardEnabled`,
  `IME_FLAG_NO_PERSONALIZED_LEARNING`): Flutter spells it
  `enableIMEPersonalizedLearning: false`.
- **Bubble measurements**: this app's own `signal_bubble_metrics.dart` port,
  reused rather than re-measured, plus `ghostClusterPosition` — the timeline's
  clustering rule (same sender, same minute, text only), with files excluded.

NOT taken: Signal's view-once flow lives in the database
(`ViewOnceMessageManager`). Ours has no row to expire: the photo timer above
zeroes RAM and tells the other phone over the channel.

## Deliberately absent

Voice notes, reactions, replies, read receipts, groups, iOS
screenshot blocking, web and desktop. None of them has a design yet that keeps
the "nothing stored" promise cheaply.

## Tests

`test/features/ghost/ghost_frames_test.dart` (protocol, file names,
reassembly, budget), `ghost_item_rules_test.dart` (timer decode, fail-closed,
no save beside a timer, `viewed` frame) and `ghost_signal_seal_test.dart` (seal/open, session and
sender binding, tamper, no replay as a message). Server:
`services/ghostchat/*_test.go`, `services/chat/ghost_policy_test.go`.
