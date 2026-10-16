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

# Conversation, chat list, and calls tab stay portrait

`MessagesScreen`, `CallsScreen` (the shell call-history tab), and
`ConversationScreen` wrap `PortraitLockScope`
(`shared/widgets/portrait_lock_scope.dart`). Landscape + keyboard overflowed
the timeline/composer by a few pixels; the list tabs match that tall-viewport
layout. The scope locks to `portraitUp` / `portraitDown` while mounted.

Nested locks share a depth counter — popping a conversation does not unlock
while the chat list underneath is still showing. Free rotation
(`DeviceOrientation.values`) returns only when the last lock disposes.

Do **not** put this scope on `/call` or `/group-call` — those need landscape.
Leaving chat via `go('/call')` disposes shell tabs and unlocks again.

# The conversation timeline is Signal's

Rebuilt 2026-09-03. The chat used to be Slack: every message a full-width row
with an avatar and a name, your own included. It is now bubbles — yours right
on the accent, theirs left on a raised surface.

## Typing indicator — header + timeline bubble

Header subtitle still shows "typing…" (DM) / "Alice is typing…" (group). In a
**DM with a peer and in a group** the timeline also bumps an animated
`HugeIcons.strokeRoundedThoughtBubble` at the newest end
(`chat-typing/typing_bubble.dart` + `typing_thought.dart`, slot decided by
`typingBubbleSlot`). A group also shows WHO: up to three overlapped faces in
the incoming-avatar gutter (`typing_avatars.dart`). A typing frame carries only
id + name, so the picture is that person's newest loaded message's avatar,
else an initial. Do not drop the header when adding the bubble — both are
intentional. Note-to-self and feeds never type.

## Autolink in bubbles

`TiptapViewer` → `TiptapInline.linkify` runs `detectAutolinks` on every text
node (`tiptap_autolink.dart`). `https://`, `www.`, emails and phone numbers
(BD `01[3-9]…`, `+880…`, formatted) become tappable: browser / mailer /
dialer. A URL wins if a number sits inside its path. Invoice-like digit
runs stay plain text. Link ink is theme-aware (`tiptapLinkColorFor`): deep
blue on light, soft sky on dark — the old single sky washed out on the
light wallpaper.

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

## Group system events (not bubbles)

`message_type=system` (name/photo/member/role/privacy/pin, …) is a quiet
centered gray line — WhatsApp/Signal style — never a Signal bubble.
`GroupEventRow` + `groupEventLabel` mirror web `group-event-row.tsx`: the
sentence is built on device from `meta.event` so the viewer reads "You…";
`body` is only the unrecognized-event fallback. Wired in
`message_list.dart` ahead of the call-event branches.

Same-day consecutive system rows (≥2) fold into `"N group updates"` via
`ChatTimelineGroupEvents` + `GroupEventsCollapse` — same shape as call
collapse. A real chat message (or a day break) ends the run; until then
every update stays in one stacked disclosure.

## Where the numbers come from

`chat-timeline/signal_bubble_metrics.dart` holds Signal-Android's own
measurements with the resource names they came from, next to
`signal_message_menu_geometry.dart` which does the same for the long-press
overlay. **Read those, do not re-measure from a screenshot.** The reference
checkout is `examples/Signal-Android`: AGPL, read-only, never a source to paste
from — the Dart here is written fresh against the values.

Corner radii are the load-bearing part. `signalBubbleRadius` collapses a run's
corners on the sender's _own_ side — right for yours, left for theirs — which
is what makes three bubbles read as one block. It is pure and tested
(`test/features/messages/signal_bubble_metrics_test.dart`); change it there,
not in a widget.

## Rules that are easy to break

- **Colours come from `SignalBubbleColors`, never from `Theme.colorScheme`
  directly.** Text on the outgoing bubble sits on the accent fill, so
  `onSurfaceVariant` is invisible on it. `MessageBody`, `MessageBubbleFooter`
  and `MessageDeliveryStatus` all take the pairing as a parameter for this
  reason. The one exception is a picture or video (caption or not): the footer
  sits on the photo, so it takes a light overlay colour (`onMedia`) rather
  than the bubble's muted foreground.
- **A picture or video overlays the footer on the image** (bottom-right, no
  scrim), including when it has a caption. Do not pad a strip under the media
  for time + ticks, and do not paint a gradient behind them — the photo is
  the surface. The caption sits below with the usual inset. Quotes and
  text-only bubbles keep the footer under the content.
  The tile fits inside `mediaMaxWidth` × `mediaMaxHeight` keeping the file's
  aspect (`soloMediaSize`) — tall media shrinks width at the height ceiling;
  never stretch every photo to the ceiling. An image/video-only message (no
  caption) paints no bubble fill — `isBareMediaBubble` / `MessageBubble.transparent`.
  **With a caption, the media decides the width and the caption wraps to it**
  (`MediaCaptionLayout`, Signal's rule), and a solo photo/video takes the
  240dp `mediaMinWidthWithCaption` floor (cropped, `BoxFit.cover`). In a
  plain Column the caption laid out against the bubble cap, so a portrait
  photo sat beside a strip of bare fill as wide as the text.
- **Do not wrap bubble content in an `Align`.** An `Align` stretches its parent
  to the full width cap and every bubble reaches the far edge. The footer is
  always trailing (`crossAxisAlignment: end`) so time + ticks sit on the
  right inside every bubble — own or theirs. Media bubbles use `Positioned`
  bottom-right on the image, not an `Align`.
- **The avatar hangs off the bottom of a run, not the top**, and only in a
  group. A DM shows no avatar and no sender name at all. The slot is held for
  every message of the run so the bubbles stay in one column.
- Sender-name colours are per-user and derived from the id's code units, not
  `Object.hashCode` — Dart may vary that between runs and the colour has to
  survive a restart.
- The unread divider is placed by _count_, not timestamp: the conversation
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

The app has quotes _and_ threads. `ComposerReplyTarget.resolve` is the only
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

- In a DM the quoted text arrives as **ciphertext**, keyed to the _quoted_
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

Tapping the reaction pill on a DM or a group opens `showReactionDetailsSheet`
(`reaction_details_sheet.dart`): All (when there is more than one emoji) plus
one tab per emoji, people underneath. Each user carries `user_name` and
`avatar_url` from `users`; the sheet also fills a missing photo from the
feed / DM peer / your profile. A tap on **You** toggles that emoji off, a tap
on anyone else opens their profile. Adding a reaction still starts from the
long-press bar.

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
category `Lo` — a _letter_. `U+2800 BRAILLE PATTERN BLANK` is `So` — a _symbol_.
So a name built from them passes every category check, is not whitespace, is not
a control character, and renders as nothing: the chat row keeps its avatar,
timestamp and preview, and has no title to read, say or report. That is why they
get chosen. `safeDisplayName` returns its fallback for a name that draws nothing,
and `handlers/me.NormalizeDisplayName` now **rejects** one outright, so it cannot
be set again through our API. A blank glyph _beside_ real text is still fine.

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
the name _you_ file someone under on _your_ phone. Keyed by user id, not
conversation id, so one nickname follows a person through their DM, every group
they are in, and the sender line above their messages.

Stored in `SharedPreferences`, like the chat wallpaper, and deliberately not
synced: a nickname is a private note, and syncing it means it could leak back to
the person it describes. `ContactNicknames.titleFor` is the single decision
point — a DM takes the nickname, a group or channel never does, because nobody
has a private name for a room. Edited from Nickname on the chat details screen,
and searched in the people list, since a rename has to be how you find someone.

## Chat wallpaper is device-local; the theme pair is always the fallback

`features/messages/wallpaper/`. Global default plus per-chat overrides in
`SharedPreferences`. Unset / stored "none" always paints the bundled `mobile`
light/dark pair — there is no plain opt-out. Dewdrop and rainy-paddy remain
picker options. Per-chat choices always win over the global default.

The Meet/Talk pill (`CallActionPill`) is frosted glass — `BackdropFilter`
plus a light tint, never a solid container colour. The chat header bar itself
stays the theme surface.

## Chat search is chats, then messages

`chat-list/chat_search.dart`. Signal-Android's conversation-list search
(`ConversationListFragment.mapSearchStateToConfiguration`) draws **Chats**
first — threads whose contact name or group title matches — and **Messages**
under them. We keep that order and that pair only. Groups-in-common, contacts
without a thread, and Documents/Links/Photos chips are not on this screen.

Name matching is local (`chat_search_matches.dart` + `matchesNameQuery`) over
the sidebar, including nicknames, so a hit appears before the message index
returns. One non-empty character is enough on-device — local name match and
`LocalMessageSearch` kick off on the first keystroke. The server message index
is only asked at **two or more** characters so a single letter does not fan
out a network search.

**Search from chat details stays in that chat** (2026-09-23). It used to list
global name-matched chats and open the whole conversation on a hit, which read
as the global search. Now `openChatSearch(conversationId:)` draws no Chats
section, `searchMessages(q, conversationId:)` narrows the LOCAL index in SQL
(drift `search` / `encryptedPage` take the id — otherwise the global newest-30
cap crowds a chat's hits out), and a hit closes the search with the MESSAGE
id: details pops with it and the chat header walks the timeline there, the
same path as a pin. The server index reads plaintext only, so its answer is now
MERGED with the local, vault-decrypted hits instead of replacing them — before,
an encrypted DM's hits vanished the moment the server answered.
The floating shell pill is hidden for the duration (`shellBottomBarHiddenProvider`),
because `showSearch` does not leave the shell navigator.

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
_names_ are then handled honestly — Signal appends `-1`, `-2` — because saving
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
- `VideoThumbnails.forFile` memoises the _future_, so two bubbles on the same
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
  are gone — Save, Rotate and Share sit on a floating capsule at the
  **bottom-center** (`ImagePreviewDockSlot`). A `Center` under the fullscreen
  `Align` expands and parked the capsule in the middle of an avatar/banner
  preview. Rotate is view-only (90°); Save/Share still write the original file.
  `ChatMediaPreviewMeta.of` only fills the second line (`You · 10:00 AM`).
  Shared-media cells have no sender, so that line is the album index or empty.
- **Icons are Hugeicons free stroke-rounded** (`PreviewIcon` /
  `PreviewIcons` in `shared/widgets/preview_icon.dart`). Shared preview
  widgets must not import `ChatIcon` from messages.
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
- **anything else** → `VaultIdentityState.unlock`. Since 2026-10-16 the phone
  asks for no code (`DELIVERY_ONLY.md`, phase 3): `VaultGateRecoveryChoice`
  offers "Continue with local backup" or "Continue without restoring", both a
  new identity. `VaultGateRecoveryCode`, the "save your code" screen and
  Settings → Recovery codes are deleted; `unlockWithRecoveryCode` stays in the
  vault, unused by the UI, until the rest of phase 3 lands.

A correct code restores the _same_ identity, so every message the account ever
received decrypts.

**The newest page of every chat is pulled once after that code, not when a
chat is opened.** `MessageVaultGate._finish(pullHistory: true)` sets
`HistoryRestoreFlag` and `startHistoryRestoreIfNeeded` walks the sidebar.
It is **not** `loadFeed`: restore writes SQLite, acks delivered, follows
auto-download, and never marks read or touches the in-memory feed. An open
chat is skipped so the timeline keeps ownership. The list shows
`HistoryRestoreBanner` while it runs.

**The banner counts messages, not chats** (2026-09-27): "Restoring
messages… 1,234 / 5,678". The total is `POST
/api/chat/recovery/message-count {conversation_ids}` — counted by the server
with the walk's own rules (`ChatVisibleToViewerSQL`, replies only under a
visible root with a live reply, content-purged rows out), pinned against a
real `ListChatMessages` walk by
`db/chat/e2ee/recovery/chat_recovery_count_integration_test.go`. The phone
adds each saved page's `messages.length`. No answer (old server, offline) =
the running count alone. Label: `historyRestoreLabel`.

The flag is the whole "once" guarantee. `complete()` runs when the job
finishes (success, failure, or nothing to pull). `mark()` is a no-op after
that, so a later launch or opening a DM cannot start another sweep. A kill
mid-run leaves `pending` set and bootstrap resumes **that** first restore,
then completes. Account switch and start-fresh call `clearAll()`; normal
sign-out preserves it with the rest of the local archive. Ordinary
`restoreTrustedIdentity` / setup never set the flag.

Older pages stay on scroll-back, same as before. The server still only holds
120 days — this is not the encrypted archive and not history-transfer.

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
  is uploaded _and_ acknowledged, so an early manifest either describes chunks
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
  continuation. Nothing has been transferred end to end on a real device.

## Protocol v2 — batches (`history-transfer/v2/`, 2026-09-19)

A QR with `v=2` takes this path; `v=1` keeps the code above. Contract:
`ababilx-server/docs/history-transfer-v2-protocol.md`; shared fixtures in
`test/fixtures/history_transfer/` (the web repo pins the same files).

```
plan     message batches sealed to disk (gzip NDJSON, conv before msg, end frame)
         media laid out across batches as packed segments; missing files listed
batch    create -> reserve (by size) / PUT / confirm -> pages -> finalize
         final batch -> job seal -> wait until the browser COMMITS -> next batch
```

- **Messages before media**, each batch activatable alone, so the browser shows
  history while video is still moving. The next batch starts only after the
  browser commits the previous one; the relay never holds more than the
  server's outstanding allowance (409 `history_transfer_relay_busy` = wait).
- **A vanished or changed file is `omitted`, never skipped**: its stream range
  goes up as zeros so the batch stays gapless (v1's uploader could deadlock
  completion here), and the descriptor tells the browser to discard it.
  `V2Pins` keeps planned files out of the sweeper's eviction while it runs.
- **Byte-identical retries**: message chunks and descriptor pages are sealed to
  disk before the first upload; media chunks are re-sealed (the server only
  reads a chunk after confirm, so a re-PUT is safe).
- **Resume key in secure storage** (`SecureV2KeyVault`), the plan on disk; the
  chat list resumes an approved job on launch and shows it in the status tile.
- **Foreground only**: "Keep AbabilX open while sending." No background
  service; suspension pauses it and the next run resumes from the plan.
- The approval echoes the scanned `k` string byte-for-byte (v1 re-encoded it).
- Tests: `history_transfer_v2_{fixtures,crypto,export,media_plan}_test.dart`.

## Traps

- `_privateJwkFromIdentity` exists because `_publicJwkFromIdentity` emits
  `key_ops: []`. That is correct for a public key and makes WebCrypto **reject**
  the private import, so a phone→browser link would fail while phone→phone
  worked. The one case a phone cannot test on its own.
- Mobile only scans, so a phone that lacks the key starts a new identity
  (local backup or start fresh), not a QR of its own. `VaultGateResetDialog`
  (emailed-code reset) was unused and is deleted (2026-10-16).
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
  never open, which reads as "every incoming message says _Unable to decrypt_".
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
strip — only _after_ the file's PUT had finished, and it uploaded one file
before starting the next. Ten photos on a slow uplink therefore left the
composer visibly empty for as long as the whole transfer took, which reads as
the _picker_ being slow rather than the network.

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
You sheet → Local Share is BACK (2026-10-05, Local Share v2); the Settings
 row stays hidden. See lib/features/local_share/CLAUDE.md
QR glyph is always HugeIcons.strokeRoundedQrCode (header, Settings, empty
state, scan button). ChatIcon / PreviewIcon stroke is 1.2 so they stay light.
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

Now: pinned hero (illustration + one sentence + **Link a new device** + a
circular **Sign out all other devices** on its right), then a scrolling **My
linked devices** list and the end-to-end-encryption footer. Rename and Sign out
live in each row's ⋮. The hero stays fixed so Link stays reachable on a long
list; the circular logout is disabled when this phone is the only session.
The current session never offers Sign out here; that is Settings → Sign out,
which ends authentication but preserves this device's message key.

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
disk, it moves the _key_ to where the messages already are.

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
  (`ababilx-server/db/chat/sidebar/chat_sidebar_preview_sql.go`, pinned by
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
- **The timeline body is keyed** (`ValueKey('timeline-body')` in
  `chat_timeline_view.dart`). Entering or leaving the mode swaps the header
  and the composer at the same moment. With both ends of the Column changed,
  unkeyed middle children cannot be matched, so the list was rebuilt with a new
  ScrollPosition at 0. That threw the reader to the newest message on every
  Select and every exit (fixed 2026-09-23). Pinned by
  `selection_scroll_keep_test.dart`.
- Deliberately absent: Signal's Details, star and "select all". We have no
  message-details screen and nothing stores a star, and a dead row is worse than
  a missing one. Pin is single-message only (long-press menu, see below).
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

# A mounted media tile never changes height (2026-09-19)

Reported as "scrolling down in a chat with photos jitters, and sometimes it
bounces back up before I reach the newest message". The list is
`reverse: true`, so scrolling toward newer messages builds rows BELOW the
viewport first — and a caption-less photo changed height three times after it
was laid out:

```
frame 1   no handle yet (autoDispose provider)   -> placeholder 210dp
frame 2   file found, not decoded                -> Image min height 100dp
~50-300ms full-resolution decode finished        -> 240 x ratio, up to 420dp
```

Every change to a row below the viewport shoves every row above it, which is
what the reader is looking at. Scrolling up never showed it: rows appear at
the top there and push nothing. `media_scroll_test.dart (caption=false)` had
been failing for exactly this.

```
size       measured ONCE from the file header when bytes land
           (download, sender adoption, or lazily for older files)
           -> attachment_blobs.media_width/height (schema V8) + memory
tile       picks its frame at MOUNT (MediaFrameLock); a late size only
           when nothing on screen moves (canResizeMediaFrame)
first frame  AttachmentHandleMemory: last handle + size, read synchronously
decode     ResizeImage at box x devicePixelRatio, cover, never upscaled
```

- **The rule is "a mounted tile never resizes where the reader would see
  rows move", not "a mounted tile never resizes".** A size learned after
  mount is taken only when `canResizeMediaFrame` (`media_frame_shift.dart`)
  allows it: the tile is wholly past the trailing edge (above the screen in
  the reverse list), or it is not below the screen AND the list is not
  scrolling. A tile below the viewport, the one that caused the jitter, still
  waits, for a later scroll that brings it up or for the next mount. The
  first version held every late size until remount, and that was a bug
  (fixed 2026-09-23): a photo or video that ARRIVED while the chat was open
  mounted before its bytes existed and stayed a squashed 210 square until
  the chat was reopened. An on-screen resize moves only the rows above the
  tile, just as a new message arriving does. The listener exists only while
  the size is unknown, so a known-size row costs nothing. Pinned by
  `media_tile_frame_test.dart` and `media_frame_late_shape_test.dart`.
- **The server sends no dimensions**, and this is the mobile-only answer. A
  photo that has never been downloaded still mounts at the default 240x210
  frame, and takes its real shape once downloaded, if that moves nothing. Signal carries width and
  height in the attachment pointer; doing that means a server column plus
  every sender, and was deliberately left for later.
- **Sizes are loaded before rows mount**: `warmMediaFrames` runs one indexed
  query per page (cold-open hydrate, network page, disk page) ahead of
  `setFeed`, bounded at 250 ms so a slow disk only costs a default frame.
- **`ImageDescriptor.encoded` reads the header, allocates no pixels**, and
  answers through the same codec that later decodes the file, so EXIF
  orientation agrees. A video's size is its poster frame's
  (`VideoThumbnails`, Android). A measurement that hangs times out at 3 s —
  the runner waits for it before announcing "ready".
- **Memory is told when a file leaves disk** (`AttachmentBlobStore.onForget`
  on markAbsent / delete / clearAll), so the first-frame fallback never offers
  an evicted path. The size survives eviction on purpose. Cleared with the
  authority on logout and wipe.
- **Decode at display size.** Full-resolution decode of a 12 MP photo is
  ~48 MB against Flutter's 100 MB image cache; every pass through a photo
  chat evicted and re-decoded. `displaySizedImage` covers the box on this
  screen's density and no more.
- **Rows are keyed** (`timelineRowKeys` + `findChildIndexCallback`). Before,
  a new message at the bottom shifted every index, and each built row's
  element was handed the message beside it — every visible photo re-looked-up
  its file and re-picked its frame at once.
- `MessageBody` keeps media under one `Stack` whether or not the footer
  overlays it: the footer comes and goes as a run grows, and a changed tree
  shape remounts the tile.
- Rows prebuild one viewport ahead (`ScrollCacheExtent.viewport(1)`), so a
  photo decodes before it is on screen; a first decode fades in over the
  placeholder colour (`fadeInImageFrame`), a cached one paints at once.
- Timeline and rows `select` what they read from `chatProvider`. Watching the
  whole state rebuilt every visible row on typing, presence and other chats'
  traffic, mid-scroll.
- The sending-clock pulse runs only while a message is sending
  (`MessageRowPulse`). It used to repeat forever in every row, keeping a
  ticker asking for a frame on every vsync while a chat was open.

# Opening a chat never waits on the network (2026-09-21)

Reported as "after login the restore bar counts n/n, then opening a DM
fetches from the API again instead of showing". The history was on disk the
whole time; five things stood between it and the screen.

```
open  -> buffered live copies (memory, first frame)
      -> disk page  ─┐  both start at once, neither waits on the other,
      -> network    ─┘  each merges into the LATEST state, never a snapshot
```

- **SQLCipher ran every call on one thread.** A history restore upserts 100
  messages at a time, and a DM's page read queued behind all of them.
  `ChatMessageStoreChannel` now has a reader executor beside the writer; the
  database is WAL, so a read sees the last commit while a write runs.
- **Every upserted row scanned the whole table** (`json_extract(payload_json,
  '$.id')` to drop its duplicate, and again in `keepLocalRecovery`), and
  `prune` built a set of 200 000 ids per batch. Native V2 adds expression
  indexes on `$.id` / `$.send_status` and prunes only past the cap.
- **Drift's timeline index only existed on devices upgraded through V4** —
  `createAll()` never builds hand-written indexes, so a fresh sign-in read
  every page by full scan. V9 (`chat_local_indexes.dart`) creates the timeline
  and the two expression indexes for everyone. The expressions must match the
  queries byte for byte.
- **First open of every scope migrated 2 000 rows into SQLCipher before
  answering.** Drift is a full mirror (every write lands in both), so an
  unmigrated scope is answered from Drift and migrated in the background.
- **Fifty messages unwrapped the same key fifty times** — `decryptMessages`
  is a `Future.wait`, and each `_readKey` read the envelope and ran its own
  pure-Dart P-256 agreement. `_readKeyLoads` single-flights it; pinned by
  `offline_message_decrypt_test.dart` (50 → 1).

Also in this pass (`cache_first_loading_test.dart`):

- `ReceivedMessageBuffer` keeps the decrypted socket copy for a feed nobody
  has opened; the open takes it synchronously. The persist is async, so the
  disk page could miss the message whose preview was already in the list.
- `hydrateFeedFromCache` is single-flight per feed and thread-aware; threads
  open and page back offline from their replies on disk, and the summary under
  the root (`threadRepliesByRoot`) is merged from the same rows.
- A restore pulls the open chat next (`prioritized`) and merges each persisted
  page that touches the visible window — never the whole archive.
- `ChatOpenTrace` logs `[ChatOpen] <feed> disk= decrypt= frames= paint=` in
  debug/profile builds.
- **Trap:** `future.whenComplete(() => _map.remove(key))` returns the stored
  future to `whenComplete`, which then waits on itself forever. Use a block
  body. `link_preview_loader` had exactly this — every `loadLinkPreview` for a
  new URL hung, so no preview card ever drew — and is fixed the same way.
  `attachment_dimension_reader` is safe: it stores the inner future, not the
  chained one.

# Markdown in bubbles (2026-09-21)

Bots, webhook feeds and pastes from an AI assistant send markdown as literal
text, and TipTap stores it as plain paragraphs — so the bubble showed the
asterisks. `markdown/message_markdown_source.dart` (`markdownSourceOf`) hands
such a body to `gpt_markdown` (`markdown/message_markdown.dart`); everything
else stays on `TiptapViewer`.

- **Only plain TipTap qualifies**: paragraphs of unmarked text and hard
  breaks, or a legacy non-JSON body. Real marks, lists or a mention keep the
  TipTap renderer — the formatting is already there, and a mention must stay a
  tappable chip.
- **Only when it looks like markdown** (`looksLikeMarkdown`: heading, list,
  quote, fence, table, rule, `**`, `__`, `~~`, inline code, `[t](url)`). A
  sentence with one `*` renders exactly as before.
- **Opt-in per call site** (`TiptapViewer(markdown: true)`): the bubble and
  the long-message screen. Wall and board are unchanged.
- Headings are scaled off the bubble's text size, not the app's display
  styles. Links open only http/https/mailto/tel — the sender wrote them.
- "(edited)" sits under the body right-aligned: markdown ends in a block, so
  it cannot join the last line as TipTap's trailing span does.
- Pinned by `test/features/messages/message_markdown_test.dart`.
- **Web twin**: `components/team/board/tiptap/markdown-source.ts` in
  `opensource/chat_ababilx` and `Ababil-X-frontend`, same regexes and same test
  cases. Web renders through `@tiptap/markdown` and adds hard breaks so a
  single newline stays a line break, as `gpt_markdown` keeps it here.


## Unblock connections — 2026-09-23

Mobile previously exposed Block but no blocked list or Unblock action. Blocking
removed a person from accepted connections and discovery, leaving no return
path in the mobile UI. Connections now has a Blocked people app-bar action.
`blocked_connections_screen.dart` reads `GET /api/chat/connections/blocked`
through the repository and uses `DELETE /api/chat/connections/:userId` to lift
the caller's block. The server already supports both routes and only lists
blocks owned by the caller. Unblock returns the pair to strangers; it does not
auto-accept a connection. A new request is needed to reconnect.

The action prevents duplicate taps, keeps the row on failure, offers retry,
and refreshes blocked people, accepted connections and the chat sidebar after
success. Message history is untouched. `blocked_connections_test.dart` covers
the endpoint/peer-id contract, success, duplicate taps, failure and list retry.

## Personal message pins — a list in chat details (2026-09-23)

Each member pins any number of messages (cap 50) per conversation, for
themselves only. Long-press a sent top-level message → Pin message; a toast
says where to find it. **There is no bar over the timeline any more**: chat
details → **Pinned messages** (count as the value) opens
`/messages/:id/pins` (`chat-pins/`), built to Telegram's "N Pinned Messages":
the chat's wallpaper, the timeline's own bubbles (`MessageRowContent`, so
names, reactions and media match the chat) in chat order with the newest at
the bottom, a round go-to arrow beside each, a floating back button + title
pill (same header as the group members page), and **Unpin all** as a
floating pill at the bottom centre (`unpin_all_fab.dart`; confirm, one DELETE each — no
bulk route — then close). Long press a bubble for Go to / Unpin. Tapping a
bubble or its arrow pops the pins screen and details with the message id
(`context.pop(id)`), and the chat header that pushed details walks the
timeline to it (`jumpToPinnedMessage`). Pending, purged and thread replies cannot be pinned.

Server: `0156_chat_message_pins_v1.sql` adds `chat_message_pins
(conversation_id, user_id, message_id, pinned_at)` and carries over 0155's one
pin; `chat_conversation_members.pinned_message_id` is left unread.
`GET .../pinned-messages` returns `{pins:[{pinned_at, message}]}` — the message
as the timeline serves it (ciphertext included, opened on the phone through
`decryptIfNeeded`), via `chatdb.ListChatMessagesByIDs` under the viewer rule.
`PUT|DELETE .../pinned-messages/:messageId` pin/unpin, both idempotent; 409
`chat_message_pin_limit` past 50, 404 when the message is not a visible
top-level message of this chat. Both prefixes. The old single-pin
`GET|PUT .../pinned-message` stay for older builds: read = newest pin, write =
add, empty id = remove the newest only.

`pinnedMessagesProvider` is the list; `pinnedMessageIdsProvider` feeds the
long-press Pin/Unpin label, and `ChatTimelineView` listens to the list so it is
loaded while the chat is open. Widget tests that mount the timeline or details
use `test/features/messages/no_pins_override.dart`.

**"This message is no longer available here" on a message that was there** —
the jump walker scrolls to the top of what is loaded, which is exactly where
the list's own scroll listener starts `loadMoreFeed`. The walker's own call
then returned at once (a page was in flight) and it read the unchanged extent
as the end of history. `ChatTimelineJump._olderPageSettled` now waits for the
in-flight page (`loadingMore` false) before measuring. The 40-screen search
limit still stands; a message past it reports honestly.

## Block / Unblock on DM details — 2026-09-23

`chat-details/details_block_tile.dart` draws **Unblock** when the caller owns
the block, **Block** otherwise. `lock_reason: blocked` is the same for both
people, so direction comes from `blockedConnectionsProvider` (server lists only
the caller's own blocks) — a block the peer placed never reveals itself. While
that list loads on a blocked chat the row draws nothing. Neither action leaves
the screen any more (Block used to jump to `/messages`); the row flipping is
the confirmation. Unblock is the same `DELETE /api/chat/connections/:userId` as
Blocked people and does not restore acceptance. Pinned by
`details_block_tile_test.dart`.

## Cold-start avatars (2026-09-25)

Group photos appeared only after the network answered on every launch because
`chat_conversation_json.dart` (the sidebar cache's writer) never saved
`avatar_url` — cached rows came back with no photo, so the list drew the
member stack or the bare icon until `fetchSidebar` finished. It now saves
`avatar_url`, `banner_url`, `description`, the two role switches, `my_role`
and `peer_user_email`; `sidebar_cache_identity_test.dart` pins the round
trip. **Any field `fromJson` reads must also be written by `toJson`**, or it
silently disappears on an offline start.

`AppAvatar` (`shared/widgets/`) reads through its own `AvatarCache`
(`avatars_v1`, 2000 files, 365 days, app cache dir — never the gallery), so
wall and shared photos no longer evict faces out of the default 200-object
store. It decodes at the drawn size (`memCacheWidth`, 2x for landscape crops)
and has no fade, so a disk hit shows at once.

Every identity picture outside `AppAvatar` reads the same store: covers and
group banners (`GroupBannerHeader`, the group edit surfaces), the call
screen's photo and blurred backdrop, board and CRM avatars, CRM organisation
logos and the webhook picker (`AvatarCache.provider(url)` wherever an
`ImageProvider` is wanted). The full-screen viewer opened from an avatar
(`PreviewImage.identity`) reads it too, so the tapped photo opens without a
second download. The viewer's remote fallback for everything else is now
cached as well; it was a bare `Image.network`.

## Online dots and "Online / Offline" (2026-09-25)

The phone never drew anyone online. The server has fanned
`attendance.presence` / `attendance.presence.snapshot` out to every socket
since 2026-09-07 (audience = teammates + accepted connections, minus anyone
the peer is private toward), but no mobile provider listened.

- `features/presence/online_presence_provider.dart`: userId → when the
  phone heard they were online, the 90 s TTL web uses. Stamped with the
  phone's own clock (not the event's `at`), so a skewed clock cannot expire
  events on arrival. A 15 s sweep drops expired entries so a dot goes out
  without an unrelated rebuild. Our own socket dropping clears the map. The
  reconnect brings a fresh snapshot. Booted and shut down in `CallStoreSync`
  beside in-call presence and user status.
- Chat list: `chat-list/conversation_avatar.dart` (moved out of
  `conversation_row.dart`) puts `OnlineDot` on a DM peer. It is always a
  Stack, so the dot toggling never remounts the picture.
- DM header: `PeerPresenceLabel` sits after typing, Privacy, in a call and
  custom status. "Offline" shows only when `request_state == 'none'`. An open
  request never receives presence, so "Offline" there would be a guess.
- Snapshot missed when the socket connected before the provider subscribed?
  The server's minute-tick re-broadcast (`RefreshConnectedPresence`) fills it
  within 60 s.

# Private chat: this phone IS the only copy (2026-09-26, server 0160)

**Since 2026-10-16 (server 0173, `DELIVERY_ONLY.md`) everything below applies
to every `held` message, not only private chat**: custody, the pull, ops.
`ChatMessage.heldForPhones` is the storage test; `privateChat` is only the
quiet rules (no save / share / forward). A forward the server answers 404
for a held message re-sends from this phone (`chat-forward/forward_resend.dart`).

Full contract in the root `CLAUDE.md`. What bites on this side:

```
arrives (WS / page / pull)  ->  messageStore.saveAll  ->  takePrivateMedia
                            ->  POST /api/chat/private/custody   (never before)
```

- **`takePrivateCustody` is the only thing that may confirm custody**, and it
  runs from every path a private message can arrive by: `_onMessageCreated`,
  `_onMessageUpdated` (a timed photo expiring releases its held message), both
  feed page loads, `pullPrivatePending` and — for this phone's own sends —
  `sendMessage` right after confirm (its socket echo lands as already settled
  and returns early). It takes OWN messages and ops too: the server holds them
  for the author's phones as well. Reordering it so the POST comes before the
  disk write or the download loses the message for good — the server deletes
  on that POST. Only `ready` counts as downloaded; never treat
  `permanentlyFailed` as taken.
- **`pullPrivatePending` runs at bootstrap and in `resyncNow`** (reconnect +
  foreground), chat opened or not; one at a time, 10 pages max, because an
  unopened timed photo comes back on every page.
- **Nothing server-side ever deletes the local row.** Purging writes no
  deletion marker and the feed merge never drops rows the server stopped
  returning. Do not add a "reconcile with server" step for private DMs.
- **Edit / react / delete go through `_ChatPrivateOpsMixin`** whenever the row
  is `heldForPhones` (`held` or `private_chat`) — `_privateTarget` in
  `chat_provider_mutate.dart` routes them. The ordinary endpoints 404 on a purged row. Received ops apply
  in `applyPrivateOp`, which checks authorship itself (`privateOpEffect`): the
  server cannot once the target is gone.
- **Quotes**: `meta.private_quote_id` is resolved in `MessageVault._decryptQuote`
  via `privateQuoteLookup` (drift `byId`), same conversation only. Drift is the
  lookup because it mirrors every write on both platforms.
- **Sidebar**: `last_message_private` rows keep the preview already on screen
  (`keepPrivatePreviews` in `fetchSidebar`); unread comes from the server's
  `private_unread`, so pulled messages never bump it again.
- Screenshot lock and "no ticks" need nothing new: the server reports
  `peer_privacy` true on both rows. `isPrivateChatProvider` only makes them
  immediate after this phone's own toggle, and swaps "Privacy" for
  "Private chat" in the header.
- Manual Settings → Data and storage clears still mark private media absent;
  the server copy is gone, so that one is permanent. Auto-eviction is not wired.

# Mute options — bottom sheets only (2026-09-27, server 0162)

`chat-mute/`: tapping Mute (details button, chat-list long press) goes
through `changeConversationMute` — muted → unmute at once, no sheet
(Signal); not muted → `showMuteOptionsSheet`: 1 h · 8 h · 1 day · 1 week ·
Always · Only mentions (groups only; in a DM every message is to you) ·
Custom. The chat header has no ⋮ — Mute and Search live in details.
Chat-list long press keeps `shellBottomBarHiddenProvider` true through the
chooser **and** the mute options sheet — restoring between them put the
pill over the mute sheet.

- **No dialog, anywhere — the user's rule.** Custom is a
  `CupertinoDatePicker` on a SECOND PAGE of the same sheet
  (`mute_custom_page.dart`), never `showDatePicker` / `showTimePicker`.
  `mute_sheet_test.dart` fails if any of those appear.
- **Read `isMutedNow`, never `muted`.** A timed mute lapses in memory with no
  event; `muted` is only the server's answer at fetch time. Same for
  `isMentionsOnlyMute` / `muteStatusLabel`.
- Presets send `for_seconds` (server clock), Custom sends `until`. The row is
  patched from the SERVER's answer (`setMute`), so a timed mute caches the end
  the server settled on; `copyWith(clearMutedUntil:)` is how "Always" drops a
  previous end time.
- The phone never suppresses a notification itself: the server skips the push.
- The web only shows the mute; control stays here. Do not port the sheet to
  the web.

# Keyboard stickers and GIFs (2026-09-27)

Reported as "can't send stickers or GIFs". Gboard, Samsung Keyboard and
SwiftKey insert them through Android's commit-content API, and a `TextField`
with no `contentInsertionConfiguration` makes the keyboard answer "AbabilX
doesn't support image insertion here". The chat field now declares one
(`composer_keyboard_content.dart`: gif, webp, png, jpeg).

- **Sent on insert, alone** (Signal / WhatsApp): the item becomes a
  `PickedMediaFile`, takes the ordinary upload path (`uploadAttachments`),
  and its `onReady` calls `_send(only: …)` — the uploading bubble appears at
  once. `only` posts those attachments and nothing else: the typed text, its
  mentions, the durable draft and the pending strip are left for the next
  send. A reply target, if one is set, is used (the sticker answers it).
- A DM where privacy mode applies still shows the timer / saving sheet first;
  that is privacy mode's contract, not a delay to remove.
- Bytes are uploaded untouched (no re-encode), so a GIF or animated WebP
  stays animated; the timeline's `FileImage` plays it.
- Offered only when the group lets this member send photos
  (`_mediaAllowed(visual: true)`); otherwise the field stays text-only and the
  keyboard says so itself. Server permission check is unchanged.
- Main composer only. The thread composer shares it; the edit sheet and Ghost
  Chat do not take keyboard images.
- Pinned by `test/features/messages/composer_keyboard_content_test.dart`.

# Encrypted chat files (2026-10-06, server 0168)

Full contract and wire format: root `CLAUDE.md`, "Encrypted chat attachments".
What bites on this side:

```
upload   notifier.presignAttachment -> SealedUploads.register(publicUrl, key)
         notifier.uploadAttachmentBytes|File -> encrypt, PUT ciphertext
         notifier.sendMessage -> SealedUploads.attach -> vault seals each key
                                 under the body's key version -> toWire()
receive  vault.decryptMessage -> _openAttachments -> real name/type/size + secret
         queue -> sealed_download.dart: ciphertext to .enc, decrypt to .dec, rename
```

- **The five senders (composer, voice, camera, share intake, khaam) changed
  nothing**, because the key rides a registry keyed by the upload's public URL.
  A new upload path must go through the three notifier methods, or it uploads
  in the clear with no error. An object that is not a message attachment
  passes `plain: true` (group photo and banner).
- **`ChatAttachmentInput.toJson()` is local-only and carries the file key**
  (the outbox needs it to finish a send after a kill). The API takes
  `toWire()`, which throws for an encrypted upload with no seal rather than
  send a file nobody can open. Never hand `toJson()` to the server.
- **`ChatMessageAttachment.toJson()` writes the SEALED form** when the
  attachment was opened: generic name, coarse type, ciphertext size, no key.
  The message store therefore never holds a file key or a real file name.
  `secret` is memory-only.
- **`needsKey`** = encrypted and its key did not open here (vault locked, or a
  key version this account does not hold). Intake skips it, the queue fails it
  at once without a request, the locked-chat widgets draw a dead row. Never
  hand such a URL to an image or video widget — it is ciphertext.
- **A files-only message has a sealed EMPTY body.** Use `isUnopenedMessage`
  (retry, forward, select) and `isVaultFailureBody` (sidebar preview after a
  decrypt) — `isVaultPlaceholderBody('')` is true and would block all three.
- **Sealing is on by default**: `sealedUploadSecret` reads
  `profile.encryptedAttachments` (`/api/me`), which the server now always
  reports true — there is no env switch any more. It stays a read, not a
  constant, so a phone pointed at a server older than 0168 (field absent)
  does not upload ciphertext that server would store without its key. A
  `plaintextUntilKeyed` group is still skipped, since its send may fall
  back to plaintext. Builds before 5.3.9+39 cannot open encrypted files.
- **The cipher is `AesGcm.with256bits()` per 64 KiB chunk**, the same
  primitive the local backup and history transfer use on files. On Android
  that is `cryptography_flutter`: chunks of 2000 bytes and up go over the
  method channel to `javax.crypto` (AES/GCM/NoPadding, AAD honoured), smaller
  ones run in Dart — the same standard output either way, and the same as the
  pinned vector. Throughput on a real phone is not measured yet; if a large
  video is slow, the chunk loop is the one thing worth moving to Kotlin, with
  the identical format.
- **The key stays in `SealedUploads` until the send is confirmed**
  (`sendMessage` forgets it after the server's answer; `discardUpload`
  forgets it too). Removing it at `attach` looked tidier and was a silent
  corruption: a send that returned before reaching the outbox is repeated
  from the caller's own list, which has no key, and the ciphertext went out
  as an ordinary `.bin` file.
- **The sealed size comes from the bytes uploaded** (`SealedUploads.sizedFor`
  in the two upload helpers), not from the presign's `sizeBytes` — a picker's
  figure can be off, and the reader stops at the sealed size.
- **`uploadAttachmentBytes` streams the ciphertext** (`sealStream`), so a
  200 MB share is not held in memory three times. `uploadAttachmentFile`
  encrypts into `<cache>/att-enc/` and a cancel during that throws Dio's own
  cancel error — callers read a normal return as "uploaded".
- A stated plaintext size larger than the object is refused before anything
  is allocated (`AttachmentChunkCipher.checkStatedSize`): the size is the
  sender's, and the RAM paths allocate it.
- Locked chats, the view-once viewer and the notification picture decrypt in
  memory (`RamMediaCache.know`, `privacy_timed_sealed.dart`,
  `chat_push_image.dart`). A locked chat's encrypted video is played from the
  memory blob provider (Android), capped at `RamMediaCache.maxFileBytes`.

## Task cards (2026-10-07, server 0169)

`task/` — a DM message that is also a task. Full contract in the root
`CLAUDE.md` ("Task cards"). Mobile rules:

- The card is an ordinary message: body = title line + description
  (`taskBodyText` / `taskText`), files are its attachments, `meta.task` holds
  priority + status. `ChatMessage.copyWith(meta:)` and `meta` in `props` exist
  for this — without them a moved task does not redraw.
- `TaskCard` is drawn inside the bubble (`MessageBubbleContent._task`) and on
  the Tasks page. Files go through `MessageBody` with the body blanked, so
  locked chats, pending uploads and downloads behave as in any bubble.
- Look: the app's own — capsules (`AppCapsule`, stadium) and Hugeicons
  (`TaskIcons`) everywhere, floating capsule headers (`HeaderPill`), choosers
  are bottom sheets. No popup menu, no Material chips, no AppBar (user's rule).
- `changeTask` is optimistic and does NOT persist: the server's
  `chat.message.updated` echo carries the revision and is what gets stored.
- The change line is a group-event row; `taskEventLabel` adds the title from
  the open timeline (the server cannot — it is sealed).
- Chip sits right after Snippet in the `+` panel, DM main timeline only, hidden
  while private chat is on.

## Snippets page + capsule form pages (2026-10-07)

- Chat details → **Snippets** → `/messages/:id/snippets`
  (`snippet/snippet_list_screen.dart`). No server list exists: it pages the
  chat's shared FILES (`sharedMediaLoadProvider`, kind `files`) and keeps
  `.md` / `.txt` (`isSnippetFile`), loading on until a screenful is found.
  Hidden for a locked chat (the card reads from disk).
- Create snippet and new task share the look: `shared/widgets/
  capsule_form_header.dart` (round back, title pill, accent Send capsule) and
  `shared/widgets/app_capsule.dart` (`AppCapsule` — use it instead of Material
  chips, SegmentedButton, OutlinedButton/TextButton on these pages and their
  sheets).

# Scrollback reads the phone, not the server (2026-10-08)

Reported as "everything finished loading after login, but scrolling up in a
DM still loads from the web". It did: `loadMoreFeed` asked the server for
every older page whenever the open had a cursor, and the store was only the
fallback for a failed request. Each page of history the phone already held
was downloaded, decrypted, written back (50 `DELETE`s per `saveAll`) and
acknowledged again, behind a spinner, starting 120 px from the top.

```
inside a proven stretch  -> the store, at once, no request
at its old end           -> the server, one page: stored, then read from the store
no network               -> the store, whatever it holds
```

Signal's conversation reads its database and nothing else. Ours can do the
same only where it has PROOF the store has no hole in it, which Signal's
protocol gives for free and ours does not: the socket is suspended two
minutes after backgrounding, the hub drops a frame when a client's buffer is
full, and an open fetches only the newest 50. So two neighbours on disk can
have a hundred messages missing between them, and nothing on disk says so.

- **A `FeedSpan` is that proof** (`data/local/feed_spans.dart`,
  `feed_span_store.dart`): a stretch `[lowMs, highMs]` whose every server
  message was stored when it was fetched, with the server cursor at its old
  end and `done` once the server had nothing older. Recorded by the newest
  page at every open, by each older page, and by a finished restore walk
  (`done` for the whole conversation — after a login restore every chat pages
  from disk at once). Stretches that touch are joined. Stored in
  SharedPreferences per conversation (`chat_feed_spans_v1:`).
- **A span must leave with its rows.** One that outlives them calls an empty
  store complete. `wipeConversationLocally`, `ChatArchiveWiper` and
  `completeHistoryReset` clear it; a new place that deletes message rows must
  too. Two guards catch a miss anyway: the store running out short of a
  stretch's old end (`distrustBelow`), and the end of history being confirmed
  with the server once per session (`confirmEnd`).
- **The server lists by LAST ACTIVITY, not creation** (`ORDER BY
  last_activity_at DESC`). A thread root sits where its newest reply is, so a
  page's oldest row can be months old. `spanOfPage` therefore vouches only
  down to the oldest message WITHOUT replies, and `fromCut` keeps such a root
  off the screen until the reader reaches its own place. Drawn early it
  becomes `messages.first`, the row the next disk page is read from before,
  and everything between is skipped. A server page is shown by reading the
  store back (`showOlderFromDisk`), never from the page's own rows, for the
  same reason: the store also holds roots that arrived earlier.
- **The newest page decides whether the screen still connects**
  (`joinTopPage`). Reaches a proven stretch: nothing changes. Does not (more
  than a page arrived while away): the timeline restarts from the page and
  scrolling back walks through the hole in order. It used to draw the old
  rows straight under the new ones as if nothing were missing. The one
  exception is a reader already deep in local history nothing vouches for
  (opened offline): they are left where they are.
- **An empty page is not the end.** The cursor is a message id, and the
  server answers an id it no longer holds (deleted, or a private-chat message
  it let go) with the same empty page as "nothing older". `pullOlderChecked`
  asks again from `olderAnchors` — settled, non-private messages on screen —
  before believing it; with none to ask from, the conversation reads the
  store for the rest of the session (`serverSilent`).
- **Two pages are kept stored ahead** (`syncAhead`, `olderAheadRows`) while
  the chat is active and its history is still being proven, so the reader
  rarely reaches the old end. The timeline asks three viewports before the
  top (`chat_timeline_older.dart`), and only once the reader has scrolled.
- **`loadMoreFeed` is single-flight and returns the running load.** Awaiting
  it means "that page landed". `loadingMore` is set only while waiting on the
  server, so a disk page never flashes the spinner row.
- **The store can be stale, so a page read from it is checked afterwards**
  (`chat_provider_older_refresh.dart`). Receipts are never written to disk
  and a reaction only when its feed is loaded, so without this old ticks and
  reactions would be wrong forever. One request per page per socket
  connection, compared by the server's `revision` (`compareServerCopy`):
  unchanged rows are not decrypted or written; a receipt-only change is
  patched without decryption. Limited to pages newer than
  `olderRefreshWindow` (30 days) — older history is taken as stored, which is
  what makes a deep scroll request-free. In unproven history the same check
  runs for every page and is what inserts a message the phone never received.
- **A server-blanked copy never replaces stored content**
  (`keepingStoredContent`). After retention the server keeps the row and
  empties it; the newest-page path wrote that over the phone's copy. Now
  dropped from every page when the phone holds the content.
- **Per-page work no longer grows with the feed.** `canonicalChatMessages`
  compared every pair and re-parsed dates inside its sort; it is one lookup
  per identity and one parse per message now, and also joins three copies of
  a send in any arrival order. `TimelineModel` caches the list's derived
  items per list instance.
- `[ChatOlder] <feed> store|server|refresh rows=N Nms` in debug/profile
  builds. A healthy scroll through stored history is all `store` lines.
- **Limits.** Threads page as before (server first). A chat on an existing
  install is fetched once more on its first scroll after this build, then
  proven; only a restore proves everything up front. The in-memory window
  still grows without bound. A thread root's reply count on disk can be
  stale until its thread is opened. An edit or reaction older than 30 days
  missed while offline is not picked up by scrolling. **Not device-tested.**
- Tests: `feed_spans_test.dart`, `older_paging_rules_test.dart`,
  `older_paging_test.dart`, `older_paging_edge_test.dart`,
  `older_paging_offline_test.dart`, `older_paging_refresh_test.dart`
  (shared `older_paging_harness.dart`: a fake server that pages by activity
  and answers an unknown cursor with an empty page, as the real one does),
  `chat_message_merge_order_test.dart`.

## Send later + retry fix — 2026-10-11

**Send later** (server 0171): hold the send arrow → `send-later/`. Full
contract in the monorepo root `CLAUDE.md` ("Send later"). Phone rules:

- `chatSendBody` (`data/chat_send_body.dart`) builds the body for BOTH a send
  and a scheduled message. The server replays the stored body through the
  ordinary send handler, so a key renamed in one place only breaks scheduled
  messages days later. Pinned by `test/features/send_later/scheduled_message_test.dart`.
- `ScheduledSender` seals through `sendEncryptedChat` like a send, but writes
  no pending bubble and no outbox row. `SealedUploads.forget` runs only after
  the server stored it.
- `ScheduledMessage.asSealedMessage` stamps each encrypted file's
  `enc_key_version` with the body's — the request does not carry it, and
  without it the vault looks for key version 0 and opens nothing.
- `scheduledMessagesProvider` has no `.timeout`: a timer there outlives a chat
  opened and closed (it broke two widget tests).
- A file still uploading cannot be scheduled (no object behind the URL yet);
  the composer says so.

**Retry of a failed bubble** — three causes, all fixed:

- The pending row is written to disk as `sending` before the request and was
  never rewritten on failure, so read back from disk it showed "Sending…"
  for good and could not be tapped. `SendTracker` (`data/send_tracker.dart`)
  knows which sends are in flight; every disk read passes through
  `sendTracker.settle`, which turns the rest into `failed`.
- A failed photo/file/link bubble gave its tap to the media inside it. The
  row now absorbs pointers while failed: the whole bubble is the retry button.
- A second failure went back to "Tap to retry" with no word. `retrySend`
  returns the error and the toast says why (offline, locked, server's reason).

## The server cannot switch encryption off, and key changes are seen — 2026-10-11

Two holes found while preparing the code for open source. Mobile only, no
server change, no migration.

**1. Whether to seal was the server's answer on every send.** The
conversation type (`isEncrypted`), `plaintext_until_keyed` and
`encrypted_attachments` all arrive from it; changing any one got the next
message or file in the clear with no error on the phone.

```
EncryptionPins (message_e2ee/encryption_pins.dart, SharedPreferences per account)
pinned when   a fetched list shows the chat encrypted with no plaintext mark
              · this phone holds a key for it (vault onKeyHeld)
              · a sealed send was confirmed
then          mustSealChat = pinned OR list says encrypted
              mayStayPlaintext = marked AND never pinned
              uploads: sealed in a pinned chat; `encrypted_attachments`
              seen true once stays true (sealsUploads)
```

- Read by every path that can send: `sendMessage`, edit (`_sendEdit`: a
  ciphertext row is edited as ciphertext whatever the list says), forward
  (`buildForwardTargets(pinned:)`), send later, upload presign, and the
  notification-shade reply (reads the pins with `reload: true`, since the
  app isolate writes them).
- A pin is never removed. No conversation legitimately stops being encrypted.
- **Trust on first use.** A chat first met under a lying server is not
  protected, and a fresh install has pinned nothing. A converted group the
  phone has never seen keyed still trusts the mark.
- Unreadable storage counts as "not pinned" (the list's answer is used): the
  server cannot cause that, and a send must not fail on it.
- A NEW send path must ask `mustSealChat`, never `conv.isEncrypted` alone.

**2. The key-change watch never fired.** `SafetyNumberStore.remember` was
called only by the acknowledgement button, which is shown only after a
change, so nothing was ever stored and every check answered "first seen".
Groups had no watch at all.

```
MemberKeyWatch (safety_number/member_key_watch.dart)
first key seen for a person  -> remembered
different key later          -> PeerTrust.changed until the user has looked
sealed to a different key    -> also FLAGGED (vault onSealingTo, from
                                _createKey and the backfill), so it stays
                                reported even if the server hands the old
                                key out again when asked
```

- `safetyNumberProvider` (DM) remembers on first sight and honours the flag.
  `memberKeyChangesProvider` reads a group's `e2ee-members` roster when the
  group opens; `GroupKeyChangeBanner` names the member (from the open feed,
  else "A member") or opens a sheet when several changed. One store per
  (account, person), so a change shows in the DM and in every shared group.
- **Warns, never blocks** (Signal's rule): a person who started fresh looks
  the same as a substituted key. That includes the backfill, which hands OLD
  conversation keys to whatever key the server names for a member.
- Fingerprints are memoised per key material; a large group costs one hash
  per member per app run.
- Tests: `encryption_pins_test.dart`, `member_key_watch_test.dart`,
  `group_key_not_ready_test.dart`. **Not device-tested.**

**3. A DM key was sealed to whoever the roster listed** (same day, second
pass). `_createKey` and the backfill took every id from `e2ee-members` /
`gaps`. One extra `chat_conversation_members` row on a DM — a database write
is enough — got the new key and every older one, and no key had changed, so
nothing warned.

```
DmRosterPins (message_e2ee/dm_roster_pins.dart, SharedPreferences per account)
pinned when   a fetched list or a send names the DM's peer (first value kept)
then          _createKey seals only to {me, peer}; an unready id outside it
              is ignored; the backfill hands old keys only to the peer
Note to Self  pinned with no peer -> sealed to this account alone
```

- The vault reads the pins itself (`_dmRoster`), so a vault built by hand in
  the notification isolate is bound too (`reload` when it has no key cache).
- An extra id is skipped, not an error: the chat keeps working, sealed to
  the two people it is between.
- Groups: see 4 and 5 below.
- `EncryptionPins` also stopped overwriting the stored pins after a read
  that failed (`_read`, and a write adds to what is stored).
- Tests: `dm_roster_pins_test.dart`.

**4. Old keys were handed to whoever the server named** (third pass, same
day). The backfill re-seals keys this phone holds to the ids in `gaps`. Two
ways that gave away history, both closed in `_backfillKeys`:

```
group, new id     GroupRosterPins (message_e2ee/group_roster_pins.dart):
                  per group, who the phone has seen in the sealing roster and
                  the newest key version that existed when it first saw them.
                  A member first met at version N is never handed N or older
                  (a row added with a join date in the past got everything).
changed identity  isUnverifiedKeyChange: an identity that differs from the
                  one remembered gets NO old key, DM or group, until the user
                  confirms on the safety-number screen; acknowledgeSafetyNumber
                  then runs vault.refillKeyGaps.
```

- First roster seen is taken as it is (trust on first use); a member who
  left and came back is new again. An identity never seen before is handed
  its keys (nothing to compare with).
- A NEW message is still sealed to a changed identity and to a new member:
  warned, not blocked.
- The notification isolate (vault with no key cache) keeps no roster record
  and hands no old GROUP key; the app does on its next run.
- **Cost, on purpose:** after someone starts fresh, their old messages come
  back only when a member of that chat taps "I compared them". Before, it
  was automatic.
- `GroupRosterNotice` (capsule above the composer, "1 new person can read
  this chat" -> sheet, closing it clears it) is drawn from the same record,
  not from the server's "X added Y" line. A member added from this phone
  raises none (`expect`, in `addChannelMember`).
- Still the server's word: WHO is in a group. The phone only tells the user
  and withholds the past. Signed membership is not built.

**5. Plain text in a sealed chat is marked "Not encrypted"**
(`message_e2ee/unsealed_message.dart`, `chat-timeline/unsealed_message_mark.dart`).
The server refuses plain text into a sealed chat, so such a row was written
into the database or by the server itself.

```
DM      every plain TEXT row is marked (line = 0)
group   plain text NEWER than the oldest sealed message this phone has
        OPENED there (SealedSince, server times on both sides)
never   system / call / feed rows, files with no text, pending sends
```

- Only a message that opened moves the line, and only back in time.
- Marked, not hidden. Tap -> sheet explaining it.
- Also marked, correctly: a kanban comment relayed as a DM ("via AbabilX",
  server-written) and DM text from before DMs were encrypted (0091).
- **Not covered:** a forged row with only a file (web/desktop files are
  plain objects), the chat-list preview line, a notification the OS draws,
  a group before this phone opened any sealed message in it.
- Tests: `group_roster_pins_test.dart`, `key_change_hold_test.dart`,
  `unsealed_message_test.dart` (harness `roster_harness.dart`).
  **Not device-tested.**