# Mobile chat — outgoing message identity

Settled 2026-09-03. Do not rework the send reconciliation without reading this.

## The one rule

`clientRef` (`client_message_id`) is the stable **local** row key from the
moment a send is tapped until it is confirmed. The server id rides in the
payload. Reconciliation is an in-place update. Never delete-by-clientRef.

The server echoes `client_message_id` back on every confirmed message
(`ChatMessage.ClientMessageID`). Matching a pending bubble by `m.clientRef`
therefore also matches the settled row and empties the timeline — while the
chat-list preview (patched separately by `applyIncomingMessage`) stays correct.

Signal does the same: `MessageTable.insertMessageOutbox` then `markAsSent` on
that row. Insert-then-update, never delete-and-reinsert.

## What must stay true

- `_replacePendingMessage` identifies the pending bubble by **row id**
  (`m.id == clientRef && m.id != confirmed.id`).
- `canonicalChatMessages` treats same server id, same `clientRef`, and a
  pending row id that equals the other copy's `clientRef` as **one** message.
  A websocket copy that echoes `client_message_id` and a history-page copy
  that omitted it must not both stay on screen.
- History store accepts unsent rows. `persistOutbox` (after `encryptNew`)
  writes the ciphertext-only copy for a DM. `searchText` is empty while
  `isPending`.
- Confirm writes the same local key (`localMessageRowId` = clientRef when
  present). Absent `send_status` in JSON still means `sent`.
- `_markPendingFailed` only patches a still-pending row (`m.id == pendingId &&
  m.isPending`), so a lost HTTP response after a websocket confirm cannot flip
  the settled bubble to failed.

Web is unaffected: it has no delete-by-clientRef path.

---

# The conversation timeline is Signal's

Rebuilt 2026-09-03. The chat used to be Slack: every message a full-width row
with an avatar and a name, your own included. It is now bubbles — yours right
on the accent, theirs left on a raised surface.

## Autolink in bubbles

`TiptapViewer` → `TiptapInline.linkify` runs `detectAutolinks` on every text
node (`tiptap_autolink.dart`). `https://`, `www.`, emails and phone numbers
(BD `01[3-9]…`, `+880…`, formatted) become tappable: browser / mailer /
dialer. A URL wins if a number sits inside its path. Invoice-like digit
runs stay plain text.

## Link previews are fetched on THIS phone

`shared/link-preview/` is Signal-Android's `LinkPreviewRepository` +
`LinkPreviewUtil` + `LinkUtil`, ported; `chat-timeline/message_link_preview.dart`
is its `LinkPreviewView`. It replaced a microlink.io call whose free tier is
**25 requests per day per IP** — past that every call is a 429 and the card
silently drew nothing, which is exactly what "link previews don't work" looked
like.

```
one preview per message, attachments win
https only, and the link must survive isValidPreviewUrl
2 MB read cap, 20 redirects followed BY HAND, each hop re-checked
```

- **The one Signal rule NOT ported is the important one.** Signal unfurls in
  the COMPOSER, on the sender's phone, for a link that person just typed, and
  ships the card inside the message — a receiver never makes a request, and
  the setting is off by default. We unfurl on READ, so this runs for links
  other people sent and the link's host learns this phone's address and the
  moment the chat was opened. That is the accepted cost of having no server in
  the path.
- **`isValidPreviewUrl` is `LinkUtil.kt` line for line.** https only, no
  reserved domain (`example`, `localhost`, `onion`, `test`, `i2p`), no `..` or
  `…` in the host, no bidi override or box-drawing character anywhere, no
  private/loopback/link-local/CGNAT/ULA IP literal — and **no mixed
  ASCII/non-ASCII in the domain as written**. That last one is the point:
  `аpple.com` with a Cyrillic а would otherwise draw a card carrying Apple's
  real title and logo, a far better lure than the bare link. Read out of the
  raw string, because `Uri.host` has already punycoded it.
- **A NAME that resolves to a private address is not caught, and Signal does
  not catch it either.** Closing it needs the resolved address at dial time,
  which Dart's HTTP client does not expose. Only IP literals are refused.
- **The user agent is ours, not Signal's.** Signal sends `WhatsApp/2`. Large
  sites do key their Open Graph markup on it — Facebook answers a browser
  string with **400** on a `/share/` link — but wearing another company's
  crawler name is not something to build on. `AbabilXBot/1.0` is what desktop
  and the server send too, so all three get the same markup back.
- **The 2 MB cap is load-bearing.** YouTube serves an app shell to anything it
  does not recognise as a crawler, with `og:title` some 700 KB in. A smaller
  cap loses YouTube and nothing says so.
- **Redirects are followed by hand** so every hop is re-validated — Signal
  guards the same seam with `LinkPreviewRedirectValidationInterceptor`.
  Following them inside Dio would let one https link land on a private address
  two jumps later.
- **Two layouts, and the image's shape picks between them**
  (`isBigImagePreview`, Signal's `hasBigImageLinkPreview`): a full-width
  picture above the text when it is ≥150dp wide AND wider than tall, otherwise
  a 72dp square with the title beside it. A square `og:image` is nearly always
  a logo, and a logo stretched across the bubble reads as a rendering fault.
- **The picture is DOWNLOADED, never hotlinked** (`link_preview_image_store.dart`,
  Signal's `LinkPreviewRepository.fetchThumbnail`). Handing an `og:image` to
  `CachedNetworkImage` gave up three things at once: the URL skipped
  `isValidPreviewUrl`, so a page could aim the phone at an address on its own
  LAN; the request left with the image loader's headers instead of the crawler
  user agent; and every device re-fetched it from the host on every cold start.
  The bytes now come through `openPreviewStream` — the same guarded door, the
  same redirect re-checks — are capped at 2 MB, must carry one of Signal's five
  image content types, and land under `<app support>/link_previews/` named for
  a hash of the URL. Signal's re-encode is NOT ported: it recompresses because
  the thumbnail is about to be SENT, and ours is only ever drawn here.
- **The size is resolved at load, not in the widget**, and it comes from the
  downloaded bytes' own header (`ui.ImageDescriptor`, no pixels decoded).
  Signal never has to — the SENDER attaches the thumbnail, so its dimensions
  arrive with the message. Measuring in `build` instead would draw the small
  card and snap to the big one a frame later, on every scroll past.
- **A cached file can be gone before its cache entry is.** The folder holds 200
  pictures and the metadata store 200 entries, pruned independently, so
  `LinkPreviewPhoto` treats a missing file as an ordinary state and draws the
  fallback rather than an error.
- **The card takes the bubble's own fill**, as Signal does
  (`setBackgroundColor(getDefaultBubbleColor(...))`), and bleeds to the
  bubble's edges — which is why `MessageBubbleContent` moves the 12/7 inset off
  the column and onto the parts that still want it, the same move media-only
  bubbles already make.
- **The cache key carries a version and MUST be bumped whenever the metadata
  source changes** (`link_preview_cache.dart`, now `_v2`). Misses are cached
  (2 h; hits 24 h), so every link that failed under the old source would stay
  blank on that device even after the update that fixed it. Desktop was bitten
  by this twice. `_v2` is the downloaded-picture shape: a `_v1` entry carries
  only a remote URL nothing draws any more, so it would show its text and no
  image until it aged out.
- `LinkPreviewBuilder` is stateful on purpose: calling the loader from `build`
  hands `FutureBuilder` a new future on every rebuild, and the card blinks out
  for a frame whenever a reaction or a delivery tick rebuilds the bubble.
- **Deliberately without a card**: `thread_root_card.dart` (a condensed
  summary header — Signal drops the description there for the same reason) and
  every message carrying an attachment.
- The wall keeps its own bordered card (`shared/widgets/link_preview.dart`,
  up to three per post) and now reads the same on-device unfurl.

## Call events collapse (web parity)

Same-day consecutive `voice_call` / `group_call` rows (≥2) fold into one
`"N call events"` disclosure — web `call-events-collapse.tsx`. Pure grouping
lives in `chat-timeline/timeline_items.dart` (`buildChatTimelineItems`); the
pill + expand list is `call_events_collapse.dart`. A date break or any other
message type ends the run. A single call stays the existing centered pill.
Expanded lines use `voiceCallHistoryLabel` (Incoming/Outgoing, no duration).

## Where the numbers come from

`chat-timeline/signal_bubble_metrics.dart` holds Signal-Android's own
measurements with the resource names they came from, next to
`signal_message_menu_geometry.dart` which does the same for the long-press
overlay. **Read those, do not re-measure from a screenshot.** The reference
checkout is `examples/Signal-Android`: AGPL, read-only, never a source to paste
from — the Dart here is written fresh against the values.

Corner radii are the load-bearing part. `signalBubbleRadius` collapses a run's
corners on the sender's *own* side — right for yours, left for theirs — which
is what makes three bubbles read as one block. It is pure and tested
(`test/features/messages/signal_bubble_metrics_test.dart`); change it there,
not in a widget.

## Rules that are easy to break

- **Colours come from `SignalBubbleColors`, never from `Theme.colorScheme`
  directly.** Text on the outgoing bubble sits on the accent fill, so
  `onSurfaceVariant` is invisible on it. `MessageBody`, `MessageBubbleFooter`
  and `MessageDeliveryStatus` all take the pairing as a parameter for this
  reason.
- **Do not wrap bubble content in an `Align`.** An `Align` stretches its parent
  to the full width cap and every bubble reaches the far edge. The footer picks
  its side through the content column's `crossAxisAlignment` instead — right on
  yours, left on theirs, exactly as Signal does.
- **The avatar hangs off the bottom of a run, not the top**, and only in a
  group. A DM shows no avatar and no sender name at all. The slot is held for
  every message of the run so the bubbles stay in one column.
- Sender-name colours are per-user and derived from the id's code units, not
  `Object.hashCode` — Dart may vary that between runs and the colour has to
  survive a restart.
- The unread divider is placed by *count*, not timestamp: the conversation
  carries no last-read marker, so `ChatTimeline` snapshots `unreadCount` before
  `loadFeed` marks it read. That count is turned into a **message id** once
  (`unreadDividerAnchorId`, `chat_timeline_unread.dart`) and the bar is pinned
  to it. Never place it by offset from the end on every build — it then slides
  one row down per new message and comes to rest above the reader's own reply.
  Sending clears it, since a reply answers what it was marking.

## Thread under a bubble is a quote rail

A message with `thread_count > 0` draws `ThreadSummary` under the bubble:
a 3px primary bar (left on theirs, right on yours), `N replies ›`, the
last reply in muted gray (`onSurfaceVariant`), faces. No card, no stem.

The gray line reads `threadRepliesByRoot`, which used to fill only when
the sheet opened. `prefetchThreadSummaries` now loads that page in the
background (disk first, then the same thread list web already fetches)
so the last reply shows without tapping in. Delivered-only — prefetch
must not mark the thread read. An unopened thread with no cache and a
failed fetch is still count + the root's face only.

Helpers live in `thread_people.dart` (`threadReplyLabel`, `threadPreview`,
`threadParticipants`) and `chat_thread_prefetch.dart`
(`threadRootsNeedingPreview`) and are tested.

## Reply means two different things, and they must never both be set

The app has quotes *and* threads. `ComposerReplyTarget.resolve` is the only
place that decides which one a Reply becomes, and it is pure and tested:

- **Main timeline** → a **quote** (`quoted_message_id`). The reply stays in the
  conversation and renders `MessageQuoteBlock` above its body, like Signal.
- **Inside a thread sheet** → a **thread reply** (`parent_id` = thread root),
  with no quote. The thread already shows what is being answered.

**Never set both from one reply.** `ListChatMessages` lists the main feed with
`m.parent_id IS NULL`, so a quoted reply that also carried a parent would
silently vanish from the conversation it was posted in. That is the whole
reason the resolver exists instead of an inline ternary.

Swipe-to-reply and the Reply menu item both route through
`setReplyToMessage`, so they always agree.

## Quotes are resolved, not snapshotted

Server-side the quote is a join on `chat_messages.quoted_message_id`
(migration `0119`), so editing the original updates the quote and deleting it
leaves `deleted: true` and a tombstone. Two consequences here:

- In a DM the quoted text arrives as **ciphertext**, keyed to the *quoted*
  sender — the DM cipher binds that id into its AAD. `MessageVault._decryptQuote`
  runs it back through `decryptMessage` as a stand-in message so the key cache
  and rotation refetch are reused; the stand-in has no quote of its own, so it
  recurses exactly once. It runs **before** the outer `isEncrypted` early
  return, because an attachment-only DM carries no ciphertext but can still
  quote one.
- `messageRow` blanks `json['quote']['body']` for an encrypted quote, the same
  ciphertext-only-at-rest rule the message body follows.

The outbox needed no schema change: history rows carry the whole message JSON,
and `PendingOutboxMessages` is only a fallback for sends written before pending
messages lived in the history store — rows that predate quotes entirely.

## A quote is as wide as the message under it, and it jumps (2026-09-14)

Reported off a screenshot: a two-word reply drew a 75%-wide bubble because the
quote above it was one long line, and in the next bubble the quote card was
visibly NARROWER than the text under it. Tapping a quote also did nothing.

```
quote    asks for at most 224dp, then wraps — it never decides the width
content  the body and footer decide it
both     laid out again at the result, so the two edges line up
```

- **`QuotedBubbleLayout` is a render object, and it has to be.** A Column
  cannot do "same width as my sibling": `CrossAxisAlignment.stretch` stretches
  to the incoming constraint, which here is the bubble's cap, so every quoted
  message would be full width. `IntrinsicWidth` would answer it, but it
  measures through the whole body — and an album grid
  (`attachment_image_grid.dart`) and a link preview card are LayoutBuilders,
  which throw when asked for intrinsics. So the measuring happens in
  `performLayout`, where a second `layout()` call is legal and cheap.
- **The 224dp ask is the fix for the width complaint.** Left at its natural
  width a long quote pulled the bubble out to the cap; capped, it wraps to its
  two lines and the bubble stays the size of the reply. A short quote ("Photo")
  asks for less and changes nothing.
- **Only a quoted message pays for the extra layout** — an unquoted bubble is
  the same Column it always was.

Jumping is `timeline_jump.dart` + `timeline_jump_target.dart`, wired by
`ChatTimelineJump` and `MessageList`.

- **There is no scroll-to-index here.** `ListView.builder` holds only what is
  on screen and no row's height is known in advance, so the walk uses the one
  fact that is always true — a quoted message is OLDER than the reply, which in
  a `reverse: true` list means a LARGER offset. It jumps 80% of a viewport at a
  time, asks `loadMoreFeed` for another page whenever it reaches the end, and
  stops when the row registers its key. **Jumps, not animates**: animating each
  screen turns a month of history into a ten-second ride; only the last hop
  (`Scrollable.ensureVisible`, alignment 0.35) is animated.
- **A walk that finds nothing puts the list back where it started** and says
  "Original message not found". A tap that silently moves somebody out of their
  place in a conversation is worse than one that does nothing.
- **The wash is a colour, not a rebuild.** Every built row listens to one
  `ValueNotifier`; the row itself is passed through `ValueListenableBuilder`'s
  `child`. It reaches both screen edges for the same reason the selection shade
  does.
- **`endOfFrame` is what paces the walk**, and it schedules its own frame when
  the scheduler is idle — so this works in the app. In a widget test nothing
  pumps unless the test does: start the future, `pumpAndSettle`, then await it.
- A quote with no controller above it (the long-press overlay's floating copy)
  is not tappable at all, rather than tappable and inert.

## A mention opens the person (2026-09-14)

`TiptapViewer.onMentionTap` → `TiptapInline`, which wraps the chip — and only a
`mention` chip carrying an id, never a `wallCategory` — in a `GestureDetector`.
Chat passes the same `showUserProfileSheet` the avatar and the sender line
open, from `MessageBody` and `LongMessageScreen`.

The callback is optional on purpose: the wall and the board draw the same chip
and have no profile sheet, and a chip that swallows a tap without doing
anything is worse than a chip that lets the row underneath have it. Pinned by
`test/features/messages/mention_tap_test.dart`.

## Swipe-to-reply mechanics

`MessageSwipeReply` builds its `AnimationController`s in `initState`, not as
`late final` fields. A row that is never swiped would otherwise run the
initialiser from `dispose()`, and creating a `Ticker` on a deactivated element
throws.

---

# The long-press overlay

Rebuilt 2026-09-03 after a device report. Two things were wrong and both are
worth not repeating.

## The message is re-rendered, never photographed

It used to `RenderRepaintBoundary.toImage()` the row and float the `ui.Image`.
That produced a ~875ms frame (`Davey! duration=875ms`, 51 skipped frames) and a
crash loop:

```
Another exception was thrown: Bad state: Cannot clone a disposed image.
```

The route's future completes on `Navigator.pop`, but the **exit transition is
still painting** — so `snapshot?.dispose()` after the `await` killed the image
out from under a live `RawImage`, once per frame until the route left.

`MessageRow` now passes the message rendered again (`focused:`), a plain
widget. No image lifetime, no capture cost, and it stays crisp at any scale. If
you ever reach for `toImage` here again, remember the dispose has to wait for
the route, not the future.

The original row is hidden (`Visibility`, size maintained) while the overlay is
up, the way Signal hides `focusedView` — otherwise it sits dimmed under the
scrim behind its own copy.

## One gesture: press, drag, react

Signal forwards MotionEvents into the overlay so a single touch can press a
message, scrub across the reaction bar and release to react. Flutter routes it
for free — the recogniser that fired the long press keeps the pointer, so
`onLongPressMoveUpdate` still arrives with the dialog open. `SignalMenuPointer`
carries those global positions across, and the overlay opens on
`onLongPressStart`, not on release.

`signalScrubSelection` is the pure port of
`getSelectedIndexViaMotionEvent`, with all three gates and a test each:

- a **40 deadzone** around the touch point, so letting go without moving opens
  the menu instead of firing a reaction;
- a **vertical band** from the bar down to 30 below the touch point, so the
  drag has to head towards the bar;
- **equal horizontal slots**, seven of them — six emoji and "more".

Release over a slot reacts and closes. Release anywhere else leaves the menu
open to be tapped; closing there would make it unreachable.

The scrubbed emoji grows to 1.5 and lifts 25 with a light haptic per slot
entered, and the lifted message unpinches from Signal's 0.95
`LONG_PRESS_SCALE_FACTOR`. Numbers live in `signal_menu_metrics.dart`.

## A feed write after dispose

The same log carried `Cannot use a Notifier after it has been disposed` from
`_ChatFeedMixin.setFeed` — a conversation closed while its feed request was in
flight. Every `state =` that follows an `await` in the chat notifier now checks
`isDisposed`, which `ChatNotifier` sets from `ref.onDispose`.

---

# Names are hostile input

Added 2026-09-03, from a peer who set a name that made his row title blank.

## Every user-controlled name goes through `safeDisplayName`

`lib/shared/text/display_name.dart`. Pure, tested, applied at the render
boundary — `ChatConversation.displayTitle`, the timeline sender line, `AppAvatar`
and the CRM avatars. It drops bidi controls and zero-width characters (keeping
ZWJ and ZWNJ, which emoji and Bengali need), collapses whitespace so a name
cannot span two rows, caps combining marks at two per base, and bounds the
result at 64 runes.

**The blank-glyph rule is the one that matters.** `U+3164 HANGUL FILLER` is
category `Lo` — a *letter*. `U+2800 BRAILLE PATTERN BLANK` is `So` — a *symbol*.
So a name built from them passes every category check, is not whitespace, is not
a control character, and renders as nothing: the chat row keeps its avatar,
timestamp and preview, and has no title to read, say or report. That is why they
get chosen. `safeDisplayName` returns its fallback for a name that draws nothing,
and `handlers/me.NormalizeDisplayName` now **rejects** one outright, so it cannot
be set again through our API. A blank glyph *beside* real text is still fine.

`displayNameInitial` gives the avatar letter. Never `name[0]` — that splits a
surrogate pair and paints a tofu box for any name starting with an emoji. It
prefers a letter and takes a digit only when the name has none, because
decorative names use digit-shaped ornaments (`୨♡୧` is a pair of Oriya digits).

## People lists match on folded names

`lib/shared/text/name_search.dart` + `styled_latin.dart`. `contains` on the raw
name meant `𝕄𝕦𝕣𝕒𝕕`, `Ｍｕｒａｄ` and `⋆·˚ Murad ˚·⋆` were unfindable by typing
`murad` — the person was simply absent from the list. `matchesNameQuery` folds
both sides: styled Latin alphabets back to ASCII, Latin diacritics and Zalgo
marks off, decoration dropped. **A script's own marks stay** — a Bengali vowel
sign is `Mc`, not `L`, and folding it away would collide two different names.

## Nicknames are local, and they are the real answer

`features/messages/nickname/`. Signal's model: a display name belongs to the
account that owns it, so we sanitise it but never change it; a **nickname** is
the name *you* file someone under on *your* phone. Keyed by user id, not
conversation id, so one nickname follows a person through their DM, every group
they are in, and the sender line above their messages.

Stored in `SharedPreferences`, like the chat wallpaper, and deliberately not
synced: a nickname is a private note, and syncing it means it could leak back to
the person it describes. `ContactNicknames.titleFor` is the single decision
point — a DM takes the nickname, a group or channel never does, because nobody
has a private name for a room. Edited from Nickname on the chat details screen,
and searched in the people list, since a rename has to be how you find someone.

## Chat search is chats, then messages

`chat-list/chat_search.dart`. Signal-Android's conversation-list search
(`ConversationListFragment.mapSearchStateToConfiguration`) draws **Chats**
first — threads whose contact name or group title matches — and **Messages**
under them. We keep that order and that pair only. Groups-in-common, contacts
without a thread, and Documents/Links/Photos chips are not on this screen.

Name matching is local (`chat_search_matches.dart` + `matchesNameQuery`) over
the sidebar, including nicknames, so a hit appears before the message index
returns. Message hits stay the existing local-then-server search. Opened from
one chat's details, the message list is still narrowed to that conversation;
the Chats section stays global so you can jump. The floating shell pill is
hidden for the duration (`shellBottomBarHiddenProvider`), because `showSearch`
does not leave the shell navigator.


# Received media stays in the sandbox

`features/attachments/`. A finished download stops at
`AttachmentPaths` — application **Support**, app-private — and goes no further.
Nothing publishes to MediaStore on its own. The only copy the phone's gallery
and file manager can see is one an explicit **Save** wrote, through
`shared/media/save_to_phone.dart` (confirmation dialog, then a MediaStore
insert under `Pictures|Movies|Downloads/AbabilXStorage`).

## Why the auto-export was removed

`AttachmentExporter` used to run off the download queue's `onReady` hook and
copy every received file into the public gallery, in the name of WhatsApp
parity. Two things were wrong with it:

- The phone's photo app filled with the entire chat history. That is a privacy
  surface — anything anyone sends you is suddenly in the roll you scroll past
  people, and in whatever backs it up.
- It duplicated. The "already exported" flag (`attachment_blobs.exported_at_ms`)
  lived in the app database, and the MediaStore rows did not: reinstall or clear
  data and the ledger was gone while the public copies survived, so every file
  downloaded again and landed a second time. MediaStore does not dedupe —
  API 29+ silently renames the collision to `photo (1).jpg`, and the legacy path
  appends `(1)`, `(2)` by hand. Dedupe on content hash did not save it either:
  the same photo arriving under two R2 keys is two rows sharing one file on
  disk, and the export ran per row.

Signal's rule, which is the one we follow now: attachments live only in the
app's private store, and `AttachmentSaver` writes to MediaStore only after the
user taps Save and accepts the "other apps can read this" warning. Duplicate
*names* are then handled honestly — Signal appends `-1`, `-2` — because saving
the same file twice is a thing the user asked for.

`exported_at_ms` / `exported_path` are still on the table, never written, so
the stored schema does not need a migration to drop two unread columns.
`test/features/attachments/attachment_no_gallery_export_test.dart` fails if
anything starts calling the `media_store` channel off a download again.

Copies exported by older builds are still in the user's gallery. They are the
user's files now; nothing deletes them.


# A video bubble holds no decoder

Rebuilt 2026-09-04. Every video in the timeline used to be drawn by its own
`VideoPlayerController`, initialised, muted and paused on frame zero. Each one
of those holds a **MediaCodec decoder**, and a device has a small global pool of
them — a handful of videos in view emptied it, which is black tiles here and a
broken decode in whatever app asked next.

A downloaded video now draws as a JPEG the platform extracted once
(`VideoThumbnails`, Kotlin, cached in `cacheDir/videothumbs/`), with a play
badge and the running time over it. A decoder is created only when the video is
actually opened.

- The cache file's **name** carries the duration and frame size
  (`<stamp>.<durationMs>.<w>x<h>.jpg`) so a hit answers without opening the
  video again. The stamp hashes path + length + mtime, so a re-download
  re-decodes.
- A portrait video is stored landscape with a 90°/270° rotation flag and the
  retriever hands back the **rotated** frame — the target size has to be
  swapped too, or the poster comes out squashed.
- `VideoThumbnails.forFile` memoises the *future*, so two bubbles on the same
  file share one decode.
- Android only. A remote URL (wall, CRM) and every non-Android build fall back
  to `LiveVideoPoster`, which is the old controller-per-tile behaviour, scoped
  to the places that cannot avoid it. `NetworkVideoPlayer` is only the chooser.
- The bubble is bounded by the same `SignalBubbleMetrics.media*` values a photo
  uses, so a mixed album does not step in and out.

## Photo viewer — Signal-Android MediaPreview

Tapping a photo opens `showChatAttachmentGallery`
(`chat-timeline/attachment_gallery.dart`), built to Signal-Android's
`MediaPreviewFragment`, not the old filename + white close circles.

```
tap photo -> dark surface, photo edge to edge
chrome    toolbar (back · file name · You/sender · time)
          caption · album rail · capsule dock (Save · Rotate · Share)
tap again chrome hides; pinch-zoom and swipe stay
```

- **The file name is the title.** Asset types (`Photo`) and the 3-dot overflow
  are gone — Save, Rotate and Share sit on a floating capsule. Rotate is
  view-only (90°); Save/Share still write the original file.
- **Icons are Hugeicons free stroke-rounded** (`PreviewIcon` /
  `PreviewIcons` in `shared/widgets/preview_icon.dart`). Shared preview
  widgets must not import `ChatIcon` from messages.
  `ChatMediaPreviewMeta.of` only fills the second line (`You · 10:00 AM`).
  Shared-media cells have no sender, so that line is the album index or empty.
- **The rail is the album, not the conversation.** Signal can load every photo
  in the thread; we only have this message's images, and that is enough to
  reach the ones behind `+N`. One photo has no rail.
- **Bytes still go through `AttachmentGate`.** Chrome is paint. A page that is
  not on disk still offers the same download badge the bubble did.
- Wall / CRM reuse the same toolbar + tap-to-hide through
  `showImagePreview` (`shared/widgets/image_preview.dart`). Forward / Edit /
  Delete stay out of the viewer — those actions already live on the message.

## Video viewer — same chrome as the photo viewer

Tapping a video opens `showVideoPreview` (`shared/widgets/video_preview.dart`),
built to the same MediaPreview chrome as a photo: dark surface, filename
toolbar, capsule dock. The 3-dot overflow is gone.

```
tap video -> dark surface, video letterboxed
chrome    toolbar (back · file name · You/sender · time)
          caption · scrubber (play/pause · elapsed · slider · remaining)
          capsule dock (Save · Rotate · Mute · Share)
tap again chrome hides while playing; a pause brings it back
```

- **The file name is the title**, same as a photo. `ChatMediaPreviewMeta.of`
  fills the second line and the caption. Shared-media / wall / CRM have no
  sender, so that line is empty.
- **Rotate and Mute sit on the capsule**, not the toolbar — the toolbar stays
  identical to the photo viewer. Rotate is view-only (90° via `RotatedBox`);
  Save / Share still write the original file. An empty name hides the dock
  rather than writing `null.mp4`.
- **Pause / Play sit on the scrubber and the centre disc.** Chrome hidden
  while playing keeps the frame clean; a tap brings chrome back with a
  pause button.
- **Scrub pauses, then resumes if it was playing** — Signal's TimeBar rule.
  Remaining time is `–1:23`, not the total. A finished video seeks to zero
  on the next play; it does **not** loop.
- Chrome auto-hides after 3 s of playback and returns on a tap anywhere,
  including the letterbox (`HitTestBehavior.opaque`). The position reaches
  the scrubber through a `ValueListenableBuilder` so the video surface is
  not rebuilt on every tick.

## Document viewer — same chrome, PDF renders, office opens out

Tapping a PDF, Word, sheet, slides or zip in chat opens `showFilePreview`
(`shared/widgets/file_preview.dart`), not another app.

```
tap file  -> dark surface, same toolbar + capsule as a photo
PDF       pages pinch-zoom in place
office    kind icon + name + size; Open hands it to another app
chrome    back · file name · You/sender · time
          caption · capsule (Save · Open · Share)
```

- Chat used to `OpenFilex` straight from the bubble, so a doc never had a
  preview. `openChatAttachment` now routes through `showFilePreview`.
  Shared-media Files tab is the same row, so it gets the viewer too.
- Wall chips and CRM documents use the same entry. A PDF still renders;
  everything else is the office card. There is no Word/Excel engine here.
- The 3-dot overflow and "Open externally" bar on the old PDF dialog are
  gone.

`FLAG_KEEP_SCREEN_ON` is held only while the video is actually playing
(`VideoThumbnails.keepScreenOn`, same `com.ababilx.app/video` channel) and
released on pause and on dispose. A paused video has no claim on the screen.
Mute is state on the viewer, not read back off the controller — nothing rebuilds
on volume now.

# There is no message PIN — there is a 256-bit recovery code

Settled 2026-09-05 after one reversal. Messages are end-to-end encrypted: the
server holds no private key and cannot derive one.

The identity is minted on the device. Its private half is stored on the server
**wrapped by a 256-bit recovery code** generated here, shown once, never sent.
`MessageVaultIdentity.ensureIdentity` asks `GET .../e2ee/vault`:

- **no identity yet** → mint identity + code, wrap, `PUT .../vault/recovery`,
  return `VaultIdentityState.setup` and show the code once.
- **this phone already stores it** → loaded from `flutter_secure_storage`, asked
  nothing. If the account has no `recovery` blob (device-local era), a code is
  minted and shown — the one moment that can be fixed silently.
- **anything else** → `VaultIdentityState.unlock`, and `VaultGateRecoveryCode`
  asks for the code (`MessageVaultRecover.unlockWithRecoveryCode`).

A correct code restores the *same* identity, so every message the account ever
received decrypts.

**The newest page of every chat is pulled once after that code, not when a
chat is opened.** `MessageVaultGate._finish(pullHistory: true)` sets
`HistoryRestoreFlag` and `startHistoryRestoreIfNeeded` walks the sidebar.
It is **not** `loadFeed`: restore writes SQLite, acks delivered, follows
auto-download, and never marks read or touches the in-memory feed. An open
chat is skipped so the timeline keeps ownership. The list shows
`HistoryRestoreBanner` while it runs.

The flag is the whole "once" guarantee. `complete()` runs when the job
finishes (success, failure, or nothing to pull). `mark()` is a no-op after
that, so a later launch or opening a DM cannot start another sweep. A kill
mid-run leaves `pending` set and bootstrap resumes **that** first restore,
then completes. Account switch and start-fresh call `clearAll()`; normal
sign-out preserves it with the rest of the local archive. Ordinary
`restoreTrustedIdentity` / setup never set the flag.

Older pages stay on scroll-back, same as before. The server still only holds
180 days — this is not the encrypted archive and not history-transfer.

**The reversal is the lesson.** For a few hours this was server-side escrow with
a 6-digit emailed code. Convenient, and not end-to-end: a machine with the
server's environment key and database could read every DM. If anyone proposes
"just email a code", that is this again.

**Entropy is the distinction, not ceremony.** The retired PIN wrapped the same
blob with six digits — 10^6 behind PBKDF2, about 100 GPU-seconds. The recovery
code is 32 random bytes and uses HKDF, since stretching only helps a guessable
secret. Never wrap a stored key with something a person types from memory.

**`recovery_key.dart` has a byte-for-byte twin in `lib/chat-e2ee/recovery-key.ts`.**
Same info string, same AAD, same base64url. `recovery_key_test.dart` and
`recovery-key.test.mjs` assert the same fixed vector; change one side alone and
a code written on this phone opens nothing in a browser.

**A code cannot be shown again, only replaced.** Nothing keeps it — the pending
one lives in `MessageVault._pendingRecoveryCode` and is read once. Settings →
Message recovery code regenerates (`regenerateRecoveryCode`), which re-wraps the
same identity: history intact, old code dead.

## Linking a second device — this phone is the approver only

Web still shows a QR above its "Email me a code" fallback, because a key that
travels between two devices never passes through the server. **This phone only
scans it**; `VaultGateLink` and `DeviceLinkController` are gone, since a phone
without the key now takes the emailed code instead of showing a QR of its own.

- Approving device — `DeviceLinkApproval`, reached from the same scanner as QR
  sign-in (`QrLoginFlow.start` dispatches on the scheme). `k` comes off the
  **camera**, never from the server; that is the entire security argument, so do
  not "helpfully" fetch it from the link session.
- Both screens show six digits from `SHA-256("<crv>.<x>.<y>")[0..3] % 1e6`,
  byte-identical to the web client. Pinned in
  `test/features/messages/device_link_test.dart` — change one side alone and the
  check silently becomes two unrelated numbers.

## Sending this phone's history to a new device — `history-transfer/`

The phone is the SOURCE and only the source. A new web or desktop device draws
`ababilx://history-transfer?t=<token>&k=<ephemeral public key>&v=1`, this phone
scans it from the same scanner as the other two codes (`QrLoginFlow.start`
dispatches on the scheme), approves once, and uploads. Server side is
`/api/messaging/history-transfers/*`, migrations `0140` + `0142`.

```
snapshot   seal message chunks onto disk, plan where every file's bytes go
upload     chunk by chunk, resumable; an uploaded chunk is NEVER re-sent
manifest   seal and commit the index of what was sent — and what was missing
```

- **Why a snapshot exists at all**, when the messages are already here: gzip
  output is not reproducible and a chunk the server has accepted is frozen, so
  re-running the export after an interruption would produce different bytes for
  an index the destination may already have read. Message chunks are sealed
  into `<app support>/history_transfer/<id>/` first; the upload replays those
  files. **Media is never staged** — the attachment files already are the
  snapshot, and copying a phone's media library to send it once is the one
  thing a device short on storage cannot afford.
- **The manifest is committed LAST and freezes the transfer.** The server
  refuses new chunks after it and refuses completion until every chunk it names
  is uploaded *and* acknowledged, so an early manifest either describes chunks
  that do not exist or shuts out the ones still to come.
- **A file the phone no longer holds is recorded, not skipped** (`first_chunk:
  -1`). The message still arrives and the attachment reads as unavailable —
  which is the truth — rather than as a download that will never finish.
  `HistoryTransferOutcome.missingFiles` is reported separately from progress
  for the same reason: every message plus four lost photos is not "everything
  transferred".
- **The hash is the store's, not a re-read.** `AttachmentBlobs.contentHash` was
  computed when the file landed; re-hashing a 200 MB video per transfer would
  cost minutes for nothing. Only a row without one is streamed through
  `hashFileContents`.
- **One file is sent once**, keyed by `attachmentUrlKey` — the same key the
  destination's own attachment store uses, so a forward that shares a URL
  re-attaches on both sides without a second copy.
- **Pending and failed sends stay here** (`message.isPending`). They are not
  history, the destination cannot finish sending them, and the confirmed copy
  would arrive later under a different id.
- **Deletion markers ride in the manifest**, read at the END of the run. A
  message deleted mid-snapshot is already inside a sealed chunk; carrying the
  markers (rather than a list of revoked ids) also covers a whole conversation
  cleared while the upload was running.
- **Crypto is one random key per transfer**, sealed to the scanned ephemeral
  key — SHA-256 over the ECDH X coordinate, the device-link derivation exactly
  — and every chunk binds its index into the AAD, so dropping or reordering
  chunks fails the tag instead of producing a shorter, plausible history. The
  AAD strings are the wire format; desktop and web must match them byte for
  byte. Pinned in `test/features/messages/history_transfer_crypto_test.dart`.
- The verification code is `historyTransferVerificationCode`, deliberately the
  same six digits as the device link: one question, one derivation.
- **Not built yet**, and none of it is fake: no attempt to re-download a file
  from R2 before sending it (missing is reported as missing), no network-class
  or storage-pressure gating on the upload, no background/foreground-service
  continuation, and no destination — so nothing has been transferred end to end.

## Traps

- `_privateJwkFromIdentity` exists because `_publicJwkFromIdentity` emits
  `key_ops: []`. That is correct for a public key and makes WebCrypto **reject**
  the private import, so a phone→browser link would fail while phone→phone
  worked. The one case a phone cannot test on its own.
- Mobile only scans, so a phone that lacks the key takes `VaultGateRecoveryCode`,
  not a QR of its own. Its last resort is `VaultGateResetDialog`, which returns
  the **new** recovery code so the gate can show it — a user who just proved
  they keep nothing must not be handed a replacement invisibly.
- **After a reset, the other side hands the old key back.** The conversation
  key survives on their device — the reset only dropped the resetting user's
  envelope for it. `GET .../e2ee-key` reports the fillable versions as `gaps`
  (each with this device's own envelope), `MessageVaultBackfill._backfillKeys`
  re-wraps them for the missing member and POSTs `.../e2ee-key/backfill`, and
  their history decrypts again. It runs from `_fetchKey`, so it fires the first
  time the peer's app loads that conversation's key — one attempt per session,
  cleared on failure. Never persist a failed decrypt: `chat_message_row.dart`
  writes an encrypted message with an empty body, which is what lets a repaired
  key take effect on the next load instead of freezing the placeholder in.
- **After a reset, the OTHER side has to re-key too.** The reset drops only the
  resetting user's key envelopes, so the peer's device still holds a valid one
  and sees nothing wrong — it would keep sealing to a key the reset user can
  never open, which reads as "every incoming message says *Unable to decrypt*".
  `_DmKey.stale` (from `missing_member_ids` on `GET .../e2ee-key`) makes the
  next send rotate, and `sendEncryptedDm` in `message_e2ee/dm_key_rotation.dart`
  re-keys once on the server's 409 `chat_key_rotation_required` for a key that
  went stale mid-session. `encryptExisting` (edits) refuses a stale key instead
  of re-sealing under it; the notification quick reply uses `encryptNew` with
  the push's `sender_id` so it can rotate. Messages written before the reset
  stay unreadable — that half is the trade, not a bug.
- **Logging out preserves the key and local archive on that device.** A
  same-account Google relogin reopens it without a recovery ceremony. Switching
  to a different backend `user.id` requires an explicit destructive warning;
  only the confirmed account switch or a full vault reset removes the key.
- The reset (`POST /api/teams/chat/e2ee/reset`, 9-character emailed code) now
  carries the replacement identity's `recovery` blob in the same request. The
  emailed code is spent by then, so a client that stopped between two calls
  would leave the new identity stranded on one device — the exact dead end the
  reset existed to escape.

# An attachment tile is drawn before its bytes are uploaded

Changed 2026-09-07, after "selecting images takes time".

The composer used to call `onAdded` — the thing that puts a tile in the pending
strip — only *after* the file's PUT had finished, and it uploaded one file
before starting the next. Ten photos on a slow uplink therefore left the
composer visibly empty for as long as the whole transfer took, which reads as
the *picker* being slow rather than the network.

`composer_upload.dart` now runs in two passes:

```
reserve   one at a time, no bytes read: presign -> cache the local preview
                                        -> onAdded   (the tile appears NOW)
transfer  three at a time: read the file, PUT, adopt
```

- **Order is the reserve pass's job.** Presigning sequentially is what keeps an
  album in the order it was tapped however the transfers interleave. Do not
  move the presign into the lanes to "save a round trip".
- **Bytes are read inside a lane, never up front.** `UploadSource` describes a
  file without holding it (`composer_upload_source.dart`) — an album of ten on
  High is 30 MB otherwise, and ten videos, which are never transcoded, far
  worse. A presign needs only name, type and length, and length comes from
  `File.length()`.
- **`ComposerUploads` is not optional.** A pending tile owns a reserved URL
  whose object may not exist yet, so `_send` awaits `settle()` before posting.
  Skip that and the conversation gets a message whose photos never load, for
  everyone, permanently. It loops, because a rail tap can add work after the
  wait began.
- **A failed upload calls `onFailed`**, and the composer removes that tile. The
  object is discarded server-side in the same path, so the reservation is not
  charged.

# A feed has one picture, and it is not the group photo

A webhook feed is a conversation nobody may post into, and the server enforces
that on the whole send path — `CanUploadAttachment` rides on `CanSendMessage`,
so the attachment presign is **403 for everybody**, admin included. The group
edit sheet's photo/banner flow uploads through exactly that presign, which is
why picking a picture for a feed failed the instant the crop was confirmed:

```
+ pencil -> crop -> presign attachment  -> 403 read_only   (group flow)
+ pencil -> crop -> presign feed avatar -> 200             (feed flow)
```

- `groupEditPictures(conversation, perms)` picks the block: `WebhookEditPhoto` for a
  feed, `GroupEditImages` for a personal group, nothing otherwise. A feed gets
  **no banner** — its one picture is the face stamped on every message it
  posts, and a second one would only compete with it. The server refuses
  `avatar_url` / `banner_url` on a feed's `PATCH .../info` for the same reason,
  so the rule is enforced rather than merely intended.
- **The webhook row is the source of truth; the conversation row is the
  mirror.** `db.UpdateChatWebhookAvatar` writes both in one transaction. Every
  list row, header and details screen draws `chat_conversations.avatar_url`
  and nothing reads the hook row, so before the mirror a feed photo saved
  successfully and appeared nowhere except on messages posted afterwards —
  "uploading but not updating". Migration `0131` copies across the ones that
  were already set.
- The mirror is also what puts a feed picture under the sweeps that already
  walk a conversation's own avatar: the discard guard that refuses to delete a
  picture in use, and the delete/purge paths that queue the object.
- **A webhook message draws the feed's current picture, not its own.** The URL
  joined onto a message is whatever the hook wore when that message was
  fetched, and the local store keeps messages forever — so a photo set today
  would never reach the ones already on disk, and a photo removed today would
  go on showing on them.

# One scanner, three codes, and a QR of your own

Changed 2026-09-07. Before this the camera icon was in two wrong places at
once: the chat list header held **Local Share**, and the button beside your
name in Settings opened the **scanner** — so both people in a QR exchange were
on the same screen pointing cameras at each other, and nobody had a code to
show.

```
chat list header  ->  scanner        (the thing that reads a code)
Settings, beside your name -> /settings/qr   (the thing you hold up)
Settings -> Local Share, You sheet -> Local Share  (unchanged, both kept)
```

`QrLoginFlow.start` now dispatches on the `ababilx://` host and handles three
payloads: **desktop-login** (approve a sign-in), **link-messages** (hand this
account's message key to a new device), and **user** (somebody's handle →
`ScannedUserSheet` → `startDm`). The first two approve something and show what;
a user code approves nothing, because a handle is public. The floating shell
pill is hidden for the whole scan (`shellBottomBarHiddenProvider`) — the
camera sheet and the person-connect sheet are raised on the home navigator,
and the pill would otherwise sit on top of them the way it did on the You
sheet.

- **The payload is a handle, never a user id.** A UUID cannot be read aloud,
  cannot be revoked once a code is on a poster, and would resolve forever for
  anyone who saw it. A handle can be changed or cleared, and the same string
  works typed into people search when a camera will not focus.
  `user_qr_payload.dart` is pure and tested: it accepts `ababilx://user?u=…`
  and a bare `@handle`, and **refuses bare text** — otherwise every QR code in
  the world would look like a contact.
- **Resolution is not the search endpoint.** `GET .../chat/handles/:username`
  is exact and ignores `discoverable_by_username`, which is off by default and
  would have made the feature find almost nobody. The client calls the
  **team-prefixed** path deliberately: it is registered whether or not
  `ABABILX_INDEPENDENT_CHAT` is on, and the handler needs no team.
- **Scanning your own code is answered before the request goes out.** The
  server excludes the caller from the lookup, so it would otherwise come back
  as "no account uses @you".
- **A missing handle is the QR screen's empty state**, not an error: the code
  has nothing to carry, so it offers `/settings/username` instead of drawing an
  empty frame. `username_rules.dart` mirrors `handlers/me.NormalizeUsername` so
  Save is dead before a round trip; the server still owns the decision, and
  uniqueness is only ever settled by its index (409 → "already taken").
- Copy and Share send `@handle`, not the `ababilx://` payload — a scheme URL
  pasted into a chat is dead text on any device without the app.

# Linked devices reads like Signal's screen

Same date, `features/profile/screens/sessions_screen.dart`. The screen had a
paragraph of explanation at the top, two labelled buttons on every row, and no
way to add a device: the button that starts a link was never on it.

Now: illustration + one sentence + **Link a new device** (the scanner), a
divider, **My linked devices**, then the end-to-end-encryption footer. Rename
and Sign out moved into each row's ⋮, and "sign out all other devices" into the
app-bar overflow — a rare, heavy action does not belong under the list as a red
button. The current session never offers Sign out here; that is Settings →
Sign out, which ends authentication but preserves this device's message key.

Rows show **dates** ("Linked 26/08/26"), not "3 days ago": the list is read to
recognise a device, and a relative age answers neither question. The drawing is
widgets (`devices_hero.dart`), not an asset, so it needs no dark variant.

**Group permissions come from `chat-details/group_permissions.dart`, never
from the model** (2026-09-08, simplified 2026-09-12). `GroupPermissions(conv)`
reads the viewer's role on the row and the group's two switches — nothing
else. It used to take the team leader flag too, because a workspace channel was
run by its team; since the server's migration `0145` a converted channel is an
ordinary group and no team role reaches into chat. The edit sheet turns
`not_conversation_manager` into one sentence.

# Offline reading: the KEY is cached, not the plaintext

Fixed 2026-09-10, from a device report — with no connection, every message in
every chat drew **"Unable to decrypt this message"**: DMs, personal groups,
Note to Self, and the quoted preview above a reply. The history was on the
phone the whole time. Two independent bugs, and each hid the other.

```
BEFORE   identity  -> secure storage   (offline: fine)
         messages  -> SQLite/SQLCipher (offline: fine)
         conv key  -> memory only      (offline: GONE, and it opens both)
```

## 1. The conversation key had nowhere to live

`MessageVault._keys` was an in-memory map, so the first message after a cold
start had to reach `GET .../e2ee-key` before it could be read. With no network
that call throws, `decryptMessage`'s catch turns any throw into the placeholder,
and every bubble on screen renders the same string.

`CachedConversationKeys` (drift, schema **V7**) + `data/local/chat_key_cache.dart`
store the **sealed envelope** — byte-for-byte the ciphertext the server hands
out, openable only by the identity private key in the OS keystore. So the
"ciphertext only at rest" rule is intact: this adds nothing readable to the
disk, it moves the *key* to where the messages already are.

**This is deliberately not what Signal does.** Signal decrypts once on receipt
and writes the plaintext into its SQLCipher database, which is why its chats
have always read offline. We have the same primitive (`ChatDatabaseSecret.kt`),
but only on Android — iOS is plain drift — so storing plaintext would have been
a real regression on one platform to fix a bug on both. Caching the key reaches
the same place, on both, with strictly less at rest.

- **Rows are keyed by `(conversationId, keyVersion)`, and that is not tidiness.**
  `GET .../e2ee-key` only ever returns the NEWEST envelope, so once a
  conversation rotates, a message sealed under the retired version needs its
  own. Until 2026-09-13 this cache was the only place one could come from, so a
  reinstall restored with the recovery code lost the start of every rotated
  group. Now a miss asks `GET .../e2ee-keys?versions=N`
  (`message_vault_key_versions.dart`, pinned by `key_version_history_test.dart`)
  and stores what comes back; one request per version however many messages
  name it, and a "none held" answer is believed for a minute. `_backfillKeys`
  still caches every `gaps` envelope it sees, and now runs on EVERY key fetch
  (it used to hide behind `spent && ...`, so a past version was never refilled
  from a phone). An envelope that will not open is reported
  (`message_vault_repair.dart`) so the server takes it out of use and
  rotation/backfill heal it; `fillKeyGaps` refills other members once per
  identity at bootstrap and unlock. Pinned by `key_repair_test.dart`.
- **`_readKeys` is separate from `_keys` on purpose.** `_keys` is the key a SEND
  seals with and must stay the newest the server knows; populating it from disk
  would let a send seal under a retired version. Reading uses the version-keyed
  map, and holds retired versions quite legitimately.
- **`_readKey` consults staleness not at all.** `rekey_required` decides what
  the next send may seal to; it has nothing to say about reading a message
  written months ago. Every send path still goes through `_loadKey`, unchanged.
- Order is memory → disk → network. Disk before network also means opening a
  chat with a connection now costs **no request at all**, which the test pins.
- Wiped on confirmed account switch, on Start fresh (every envelope is sealed
  to an identity that no longer exists) and with a deleted conversation.

## 2. Being offline was tearing down a valid identity

`restoreTrustedIdentity` wrapped everything in one `try`, including its
`GET .../e2ee/vault` staleness check, and its catch called `lock()`. So an
offline launch discarded an identity sitting in this device's own keystore and
perfectly current. `ensureReady` calls it on every bootstrap, after
`MessagesScreen` had already restored offline — so the app unlocked itself and
then locked itself again, seconds later, for no reason but a failed request.

**An unreachable server is not a wrong key.** The check is advisory and can only
be trusted when the server actually answers; a failed call now falls through to
the local identity. A real answer saying the public key moved still locks and
deletes, because that copy genuinely is dead. It lives in
`message_vault_restore.dart`.

Pinned by `test/features/messages/offline_message_decrypt_test.dart` — a message
written online, then a fresh `MessageVault` against an unplugged repository.

**Still online-only, and fine:** the FCM background isolate builds its vault by
hand and passes no cache (`_keyCache` is optional for exactly that), so a push
still fetches the key. A push arrives over the network anyway.

# The socket died and nobody noticed

Reported as "I sent messages from the web, and on the phone I have to pull to
refresh to see them — both sides are online, this should be realtime." It is,
and the events were being delivered on time. To a socket nobody was holding.

```
radio changes / phone sleeps / server gives up writing
  -> TCP connection is dead
  -> nothing closes on THIS end: no FIN can reach a phone with no route back
  -> stream never ends, onDone never fires, _connected stays true
  -> WsClient reconnects never, because as far as it knows it is connected
```

Pull-to-refresh worked for the reason that makes this so easy to misread: HTTP
opens its own connection, every time. The socket beside it had been scrap since
the screen went off.

**Nothing on this side was ever asking.** `initRealtime()` ran once at bootstrap
and that was the whole of it — no keepalive, no lifecycle hook, no connectivity
listener. The server does its half correctly (ping every 54 s, `pongWait` 60 s,
`writeWait` 10 s), so it drops a phone that has gone quiet and moves on; the
phone is the one left believing.

Signal's three answers, all ported:

- **A keepalive, which is one property here.** `IOWebSocketChannel.connect` takes
  `pingInterval`; `dart:io` then pings on it and closes the socket when the pong
  does not come back inside it. That is the only thing that turns a dead radio
  into an `onDone` this client can act on. 30 s, which is
  `OkHttpWebSocketConnection.KEEPALIVE_FREQUENCY_SECONDS`. **It must be
  `IOWebSocketChannel`, not `WebSocketChannel.connect`** — the platform-agnostic
  constructor takes no `pingInterval`, which is how it went missing.
- **Foreground reconnects immediately** (`WsLinkWatch`, mounted in `app.dart`
  above `ChatStoreSync`). The keepalive finds a dead socket on its own inside a
  minute, and a minute of a chat that does not move is the entire complaint.
  Signal's `IncomingMessageObserver.onAppForegrounded` releases its connect
  semaphore for the same reason.
- **A connectivity change scraps the socket outright.** An interface swap kills
  the connection without closing it, so the old socket is rubbish whether or not
  a route exists now — `decideWsLinkAction` (pure, pinned by
  `test/core/ws_link_decision_test.dart`) says `drop` when the network is gone
  and `reconnect` when one is there. Signal's `NetworkConnectionListener`
  disconnects on the same event.

**Traps:**

- **`kick()` revives an intent, it never invents one.** `WsClient._started` is
  set by `connect()` alone, and `kick` returns early without it — otherwise a
  resume on a signed-out app starts a retry loop against an endpoint it holds no
  token for. This is why the watcher needs no auth import in `core/network`.
- **Reconnecting is only half of catching up.** `resyncNow`
  (`chat_provider_resync.dart`) re-reads the sidebar, the open conversation, its
  thread and the outbox, and runs on **both** triggers: a socket that reconnected
  has a gap by definition, and one that looked healthy the whole time may still
  have been written to while the process was frozen. Signal does the same pair on
  foreground — connect, then fetch. It no-ops before bootstrap, so a resume
  during launch cannot race it.
- **The socket is deliberately NOT dropped when the app backgrounds.** Tempting,
  and it would make resume a clean cold path — but a 1:1 call in the background
  (screen off, PiP) carries its ICE candidates on this same socket, and cutting
  it would kill live calls to fix a chat refresh.
- **Detection is still up to ~60 s** for an app sitting in the foreground when
  the link dies, against Signal's ~40 s (it pairs a 30 s ping with a 40 s read
  timeout; `dart:io` gives one knob, so worst case is two intervals). Foreground
  and connectivity cover every case anyone reported; shorten the interval before
  inventing an app-level keepalive frame.

# Chat-list previews of sealed chats (2026-09-10)

"Encrypted message" under a chat's name was two bugs, and both are gone:

```
group row    server sent the literal placeholder and NO ciphertext  -> nothing to open, ever
cached row   written ciphertext-only, painted before the vault, and
             only fetchSidebar ever opened a preview                -> offline, never opened
```

- **The group sidebar query now returns the four ciphertext columns**, from
  the same `chatSidebarEncryptedPreviewSQL()` the DM query uses
  (`ababilx-server/db/chat_sidebar_preview_sql.go`, pinned by
  `chat_sidebar_preview_test.go`). Personal groups were sealed on 2026-09-05
  and this query was never touched, so the placeholder WAS the preview.
- **One rule for both lists**, `message_e2ee/sidebar_preview.dart` — the
  mobile twin of web/desktop's `lib/chat-e2ee/sidebar-preview.ts`. Never test
  `isDm` to decide whether a preview is sealed; test the row.
- **Ciphertext at rest, text in memory.** Signal stores the decrypted snippet
  in its encrypted database. We do not, so `previewForDisk` puts the
  placeholder back on write, and `openCachedPreviews` (bootstrap, right after
  the cached paint) restores the identity from secure storage and reopens the
  rows from the stored key envelopes — no request needed.
- **A preview that will not open keeps "Encrypted message"**, never "Unable to
  decrypt this message". Down a whole list that reads as lost history.
- **The row's ciphertext follows its newest message** (`withLastMessageCipher`
  via `patchList(lastMessage:)`). A websocket message used to change the text
  and leave the previous message's ciphertext behind, so any later preview
  pass would have reopened the OLDER message over the newer one.
  `previewStillCurrent` is the second guard: it only writes onto a row whose
  ciphertext is unchanged and which still shows a placeholder.
- Web and desktop now open `channels` as well as `dms`. Their offline sidebar
  cache is unchanged (web blanks previews to "Message" on purpose).

# Chat is independent of workspaces (2026-09-12)

The server's migration `0145` turned every workspace conversation into a
personal one in place (same ids). What that changed here:

- **One route set.** `ChatEndpoints` has no `independent` switch, and the call
  constants (`chatVoiceCall*`, `chatGroupCall*`) point at `/api/chat/*` too.
  This build needs a server with `0145`: an older one with the flag off answers
  every chat call with 404.
- **No chat gate.** `chatEnabledProvider` is gone — every signed-in account
  chats and every signed-in phone can ring. No Personal/Workspaces pills
  (Personal would equal All, Workspaces would be empty), no reload on a flag
  flip, and People is always in Settings.
- **The full editor for every group.** A converted channel gets name,
  description, photo and banner through `/info`; `renameChannel` is gone. A
  reply that carries no `my_role` never demotes the row (`upsertChannel`) —
  `my_role` now parses to `''` when absent, which is what makes that
  distinguishable.
- **Group pickers offer accepted connections only**
  (`groupInvitablePeopleProvider`), the server's `CanInviteToGroup`. Workspace
  colleagues stay in New message as suggestions: the DM opens and the first
  message is a request.
- **Feeds are one kind.** The create sheet has no scope field and every feed
  call takes the `/api/chat/*` path.
- **Plaintext until keyed is the server's call, never the type's.**
  `ChatConversation.plaintextUntilKeyed` (sidebar `plaintext_until_keyed`) is
  true only for a converted workspace channel that has never had a key. Only
  then do the send path (`sendEncryptedChat(sendUnencrypted:)`) and
  `buildForwardTargets` send as-is on `ChatKeyNotReady`; a DM, a group created
  as a group, and any group once keyed fail rather than downgrade. The first
  cut gated this on `isGroup`, which leaked the converted-channel exception
  into every new group. Pinned by `group_key_not_ready_test.dart`; the rest by
  `converted_group_test.dart`.

# Multi-select: hold a bubble, then Select (2026-09-12)

Signal's action mode, ported. `chat-select/`, and the whole of it hangs off one
entry point: **long press → the overlay menu → Select**. A long press never
enters the mode by itself, because the long press already means something here
(the reaction bar and the message menu), and that is Signal's own arrangement —
`onItemLongClick` opens the reaction overlay for anything reactable, and only
its `MULTISELECT` item calls `handleEnterMultiselect`.

```
long press -> menu -> Select   enter, that message selected
tap a row                      toggle it
last one off / X / back        leave
header  -> "N selected" + X    (SelectionTopBar)
composer-> icon+label bar      (SelectionActionBar)
```

- **Ids only, resolved every build** (`MessageSelection`). Storing the messages
  would freeze what the bar may offer: an edit, a send confirmation or somebody
  else's delete all land in the feed first, and `selectedMessagesIn` re-reads
  them from it. `retain` drops ids the feed no longer holds, which is Signal's
  `onItemRangeRemoved` — without it the count promises rows no action can act
  on, and an emptied selection would leave both bars up over nothing.
- **What the bar offers is one pure function**, `selectionMenuState`, which is
  `MenuState.getMenuState` with our own rules substituted. The load-bearing
  half is Signal's: **more than one message drops reply, edit and save**, and
  forward, copy and delete are what survive. Ours differ where the app does —
  delete is withheld unless every selected message is the caller's, because we
  have no delete-for-me and the server refuses somebody else's row; a pending
  send has no server id, so it can be neither forwarded nor deleted; and a body
  this device never opened (`isVaultPlaceholderBody`) is neither forwarded nor
  copied, or the placeholder string itself gets sent. The 32-message forward
  cap is Signal's `MAX_FORWARDABLE_COUNT`.
- **The gutter is real layout, not a decoration.** Signal draws the circle and
  the shade in a `RecyclerView.ItemDecoration` over an untouched item and
  translates the item by `max(0, 48dp - itemStart)`. Flutter has no equivalent,
  so `SelectableMessageRow` **owns the list's side inset** — 16dp at rest, 48dp
  while selecting — which is why `MessageList` now passes no horizontal padding
  and every non-message item (`_inset`) carries its own. A shade inset by the
  list's padding would stop short of both screen edges.
- **An outgoing row does not move, and that is correct**:
  `getHorizontalTranslationTarget()` returns null for it, and a right-aligned
  bubble has nowhere to go. Only incoming rows shift. The widget test asserts
  both.
- Circle 22dp at 17dp from the screen edge, 1.5dp ring unselected, filled check
  selected, 150ms in and out; the shade is transparent-black over a wallpaper,
  transparent-white in dark, a wash of the accent in light —
  `MultiselectItemDecoration`'s own values.
- **Swiping is off while selecting** (`SwipeAvailabilityProvider` checks
  `isActionModeStarted()` first) and so is the long-press menu: a press picks
  rows, or the menu would offer Select on top of an open selection.
- **Back leaves the mode before it leaves the chat** — Signal's
  `handleBackPressed`, where `isInActionMode` is handled above the pop. Leaving
  the screen clears it too; the bars belong to this screen.
- **Thread panels never enter it.** They have no header and no composer slot,
  so there is nowhere to put the two bars — hence `showSelect: threadRootId ==
  null` on the menu and the same test in the row and the view.
- **Forwarding many is the single forward, looped in timeline order**
  (`chat-forward/forward_send.dart`, split out of `forward_sheet.dart`).
  Destinations are resolved **once**, or a DM created for the first message
  would be created again for the second, and the count reported is the fewest
  destinations any one message reached.
- Copy joins the bodies with newlines, oldest first — Signal's
  `copyToClipboard`, which sorts by date. Delete confirms once for the batch and
  reports a partial failure rather than stopping at the first refusal.
- Deliberately absent: Signal's Details, star/pin and "select all". We have no
  message-details screen and nothing stores a star, and a dead row is worse than
  a missing one.
- Tests: `test/features/messages/message_selection_test.dart` (the provider and
  every menu rule) and `message_multiselect_test.dart` (Select in the menu, the
  shift, the checks, and the two bars swapping in).

# The privacy policy is asked BEFORE the recovery gate (2026-09-12)

A brand-new account signed in, skipped the recovery choice (right — nothing to
restore) and then sat on **"Could not check your messages. Check your
connection and try again."** with a Retry that could never work. Nothing was
wrong with the network:

```
server  middleware.PolicyGate -> 403 policy_not_accepted on EVERY
        authenticated route but /api/me, /api/me/plan, /api/me/connections,
        /api/me/accept-policy, /api/me/delete-account
mobile  PolicyGateOverlay lives in HomeShell
router  /message-recovery is OUTSIDE the ShellRoute, and every logged-in user
        is redirected through it before the shell ever builds
```

So the one screen that must run before the shell was the one screen the policy
card could not cover, and it is the screen whose two calls — `GET
.../e2ee/vault` and `POST /api/chat/recovery/start-session` — the gate refuses
first. The account was stuck at the door with the key on the other side of it.

- **`features/policy/policy_precheck.dart` is the fix**, and it is deliberately
  two answers, not one. `policyPending(ref)` reads `/api/me` (exempt, so it
  answers) before anything else runs; `isPolicyRefusal(error)` reads the 403
  off a failure that already happened, because the profile can come from this
  phone's cache and predate a bump of `policy.CurrentVersion`. Either one puts
  `PolicyAcceptCard` on screen and re-runs `_check()` when acceptance lands.
- **A profile that cannot be read counts as accepted.** Offline is a different
  answer from "you have not accepted", and the card has no dismiss — showing it
  to somebody with no network replaces one dead end with a worse one. Their own
  request fails a moment later and reports the real reason, with a Retry that
  means something.
- **The card is wrapped in a `Scaffold` here.** It is built as an overlay (a
  70%-black `Material` scrim over the shell) and this route has nothing
  underneath it.
- The 403s in the log were not only the vault: `[ChatCache] fetchSidebar:
  network threw: … 403` is the same gate. One refusal, every call.
- Web and desktop were never exposed — their policy dialog sits in the user
  shell, and neither has a screen in front of it.
- Test: `test/features/policy/policy_precheck_test.dart`.
