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
