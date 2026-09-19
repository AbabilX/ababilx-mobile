# Calls on Android — ringtone, CallKit, audio routing

> Every line below exists because something broke without it. Read this before
> editing anything under `ringtone/`, `native/`, `audio/`, or
> `packages/call_ringer/`.

## Incoming-call ringtone — DO NOT REWORK

Shipped 2026-08-25 after a "ringtone dies ~2 s in" bug; verified working on
device.

## The bug this design fixes

`flutter_callkit_incoming` 3.1.3 rings, then kills its own ringtone:

- `CallkitSoundPlayerManager.kt` stops the tone on `ACTION_SCREEN_OFF`. Its
  `keepRingingForFullScreenIntent` guard only arms inside
  `CallkitIncomingActivity.onCreate` and lives 500 ms — and `isFullScreen: false`
  never launches that Activity, so the guard never arms.
- `CallkitNotificationManager.kt` stops the tone on **any**
  `android.media.VOLUME_CHANGED_ACTION` — not only a volume key. An OEM
  increasing-ring ramp, a Bluetooth connect, or a route change silences it.

Result: screen sleeps or volume moves → ring dead in about two seconds. In-app
ringing was fine because it never used the plugin's player. Install source
(Play Store vs sideload) is irrelevant to audio; it only affects OEM
background-start permissions for full-screen UI.

## Architecture (Signal's `IncomingRinger` shape)

One native `MediaPlayer` owns the tone for **every** path — foreground,
background, locked, killed app. Nothing else may play a ringtone.

```
packages/call_ringer/                     local Flutter plugin package
  android/.../CallRinger.kt               the one player, process-wide singleton
  android/.../RingtoneSource.kt           uri candidates + ringer-mode gates
  android/.../CallRingerPlugin.kt         MethodChannel com.ababilx.app/call_ringer
  lib/call_ringer.dart                    Dart facade, no-op off Android

lib/features/calls/
  call_ringtone.dart                      holder set + serialized apply chain
  ringtone/ringtone_engine.dart           interface
  ringtone/android_ringtone_engine.dart   -> CallRinger (holder `flutter`)
  ringtone/asset_ringtone_engine.dart     iOS only: audioplayers + watchdog
  ringtone/ring_holders.dart              `native` | `flutter`
  ringtone/callkit_ring_events.dart       the ONLY stop path for holder `native`
```

**Holders.** The player rings while at least one named holder wants it.
`native` = CallKit's incoming notification is up (taken in whatever isolate
shows it). `flutter` = the in-app `/call` screen is up. Handing the ringing UI
from CallKit to the Flutter screen therefore never gaps the sound — and
`AndroidRingtoneEngine.replayOnHandoff` is `false` so the tone does not restart
from zero.

**Player settings that are load-bearing** (`CallRinger.start`): looping,
`USAGE_NOTIFICATION_RINGTONE` + `CONTENT_TYPE_SONIFICATION` +
legacy `STREAM_RING`, and **no audio focus request** — requesting focus is what
makes a ring duck or stop when anything else touches audio.

**Stop conditions — exhaustive.** Answered, declined, ended, rung out
(`callkit_ring_events.dart`), the last holder releasing, or the 70 s
`MAX_RING_MS` backstop. The ringer is deliberately deaf to screen state, audio
focus, and volume. Adding a stop for any of those recreates the original bug.

**Plugin muted, not removed.** `AndroidParams.ringtonePath: 'silent_ring'`
(1 s silent WAV in `res/raw/`) in `native/android_call_ui.dart` and
`native/android_group_call_params.dart`. The plugin still contributes the
notification and the vibration; only its audio is silenced.

## Why a plugin package and not app-module Kotlin

Both alternatives were tried and are dead ends:

- A `MainActivity` MethodChannel dies with the Activity, so a killed app or a
  background isolate has no channel to ring through.
- A `BroadcastReceiver` on the plugin's own call broadcasts cannot work: the
  plugin builds them with `setClassName(...)`, making them explicit intents no
  third-party receiver can observe.

`FlutterEngine(context)` auto-runs `GeneratedPluginRegistrant`, so a plugin
**package** gets a live channel in every engine — UI, FCM background, CallKit
background. That is the only construction that rings a killed app.
Registration lives at `GeneratedPluginRegistrant.java` (generated; do not edit).

## Release-build traps

`res/raw/silent_ring.wav` is looked up by **name** at runtime
(`Resources.getIdentifier`) and referenced from no code, so R8 strips it and
collapses resource names. Then the plugin falls back to its default **audible**
ringtone playing on top of ours — a double ring in release only.

Two things prevent that; both are required:

- `android/app/src/main/res/raw/keep.xml` — `tools:keep` the raw entries.
- `android/gradle.properties` — `android.enableResourceOptimizations=false`
  (keeps resource _names_, which `keep.xml` alone does not).

Verify after any Gradle/AGP change:

```bash
aapt2 dump resources build/app/outputs/flutter-apk/app-release.apk | grep -i "raw/silent_ring"
```

## Deliberate behaviour (not bugs — do not "fix")

- Android plays the **user's system ringtone**; fallback order is
  `getActualDefaultRingtoneUri` → `Settings.System.RINGTONE` read directly →
  `getDefaultUri(TYPE_RINGTONE)` → bundled `raw/clear_agenda`
  (`RingtoneSource.ringtoneCandidates`). Flip that order there if a branded
  tone is ever wanted. **Every candidate is a ringtone, deliberately.** The
  notification default used to sit second in that list, which is why an
  incoming call chimed like a new message on some handsets: a phone whose
  ringtone is "None", or an OEM ROM where the first lookup returns null or
  throws, fell straight through to it (fixed 2026-08-26). Signal's
  `IncomingRinger` rings with nothing and vibrates instead rather than reach
  for the notification tone; the middle two candidates here are the same
  hardening its `RingtoneUtil` does with reflection. Do not put the
  notification tone back.
- Silent / vibrate ringer mode stays silent **in-app too** (`audioAllowed`
  checks `RINGER_MODE_NORMAL` and `STREAM_RING` volume). The old Dart player
  ignored ringer mode and played anyway.
- Notifications disabled → a `native` hold is refused
  (`requireNotificationUi`), because that call would ring with no answer or
  decline control.
- iOS is untouched: it rings via CallKit and `AssetRingtoneEngine`.

## Files that must change together

Touch one, re-check all: `packages/call_ringer/**`, `ringtone/**`,
`call_ringtone.dart`, `native/android_call_ui.dart`,
`native/android_group_call_ui.dart`, `native/android_group_call_params.dart`,
`native/android_call_background.dart`, `providers/voice_call_provider.dart`,
`main.dart` (registers the CallKit background handler from the FCM isolate),
`android/app/src/main/kotlin/com/ababilx/app/CallEventBridge.kt` +
`AbabilXApplication.kt` (+ the manifest `android:name`),
`group/providers/group_call_callkit.dart`,
`packages/call_ringer/android/.../CallkitSurface.kt` +
`packages/call_ringer/lib/callkit_surface.dart`,
`android/app/src/main/kotlin/com/ababilx/app/MainActivity.kt` (releases the
`flutter` holder in `onDestroy`), `res/raw/keep.xml`, `gradle.properties`.

The connected-call surface is its own cluster: `ongoing_call_sync.dart`,
`ongoing_call_notice.dart` (what the tray entry says, per phase),
`native/android_ongoing_call.dart`, `native/android_call_params.dart` +
`native/android_group_call_params.dart` (the `showNotification: false` that
keeps the plugin from posting a second entry), `native/android_screen_share.dart`,
`widgets/active_call_banner.dart` + `widgets/call_return_bar.dart`,
`call_status_text.dart` (the bar shows the same line as the call screen),
`app.dart` (mounts both), and
`android/app/src/main/kotlin/com/ababilx/app/OngoingCall{Service,Notification,Channel}.kt`
plus the `.OngoingCallService` manifest entry.

The display locks are a small cluster of their own:
`native/android_call_screen_lock.dart`,
`android/app/src/main/kotlin/com/ababilx/app/CallScreenLock.kt`,
`MainActivity` (attach + `onDestroy` release), `ongoing_call_sync.dart`
(`_syncProximity`), and the two call screens (keep-screen-on). The manifest
needs nothing new — `WAKE_LOCK` was already there.

Upgrading `flutter_callkit_incoming` does not remove the need for any of this;
re-read `CallkitSoundPlayerManager` / `CallkitNotificationManager` after a bump
and confirm the two kill switches, then keep `silent_ring`.

Picture-in-picture and the Signal call layout:

- `android/app/src/main/kotlin/com/ababilx/app/PipController.kt`
- `MainActivity.onUserLeaveHint` / `onPictureInPictureModeChanged`
- `AndroidManifest.xml` — `supportsPictureInPicture`, `resizeableActivity`
- `lib/features/calls/native/android_pip.dart`
- `lib/features/calls/screens/voice_call_screen.dart`
- `lib/features/calls/group/screens/group_call_screen.dart`
- `lib/features/calls/widgets/pip_call_view.dart`
- `lib/features/calls/widgets/call_backdrop.dart`, `call_top_bar.dart`,
  `call_control_button.dart`, `call_controls_row.dart`,
  `connected_call_body.dart`
- `lib/features/calls/screens/incoming_call_view.dart`
- `lib/features/calls/call_status_text.dart`

## Never end a CallKit call through the plugin directly

`AndroidCallUi.endCall` / `hideIncoming` (and their group twins) release the
`native` ring holder as part of ending the surface. Calling
`FlutterCallkitIncoming.endCall` or `hideCallkitIncoming` straight from a
provider skips that release — and terminal paths arm `_suppressCallKitEnded`
precisely so the resulting CallKit event is ignored, so nothing else stops the
tone either. That is what left the ringtone playing after a decline while every
screen had already closed (fixed 2026-08-26 in `_endNative`). Route every
dismissal through the `AndroidCallUi` / `AndroidGroupCallUi` wrappers.

## The plugin cannot close its own lock-screen call surface

Found 2026-09-03, after "I cancelled the call and it is still ringing on his
phone — he answered it and got a second ringing screen".

`CallkitNotificationManager.clearIncomingNotification` broadcasts
`CallkitIncomingActivity.getIntentEnded(...)`, and the Activity registers a
runtime receiver for that action in `onCreate` which calls `finishTask()`. The
broadcast is delivered to nobody, because the plugin builds it with

```kotlin
intent.setClassName(pkg, "…flutter_callkit_incoming.CallkitIncomingActivity")
```

and `ActivityManagerService.broadcastIntentLocked` only queries
runtime-registered receivers `if (intent.getComponent() == null)`. The manifest
pass that does run matches nothing either — the named component is an Activity,
not a `<receiver>`. So **every** dismissal the plugin performs (END, DECLINE,
TIMEOUT, `hideCallkitIncoming`) cancels the notification, stops its player, and
leaves the full-screen Activity on screen until its own `duration` timer runs
out, up to a minute later.

Only a **locked** phone shows this. With no keyguard Android draws the heads-up
notification instead of firing the full-screen intent, and cancelling the
notification is the whole teardown — which is why a cancelled call closed
cleanly in every screen-on test.

`packages/call_ringer/.../CallkitSurface.kt` sends the same intent without the
component, which matches. It is called from:

- `CallEventBridge.onCallEvent` — native, in every process, on ACCEPT /
  DECLINE / END however they were raised, so a killed app is covered too;
- `AndroidCallUi.endCall` / `hideIncoming` and their group twins — `endCall`
  broadcasts nothing at all when CallKit no longer holds a record for the id,
  and `hideCallkitIncoming` raises no event for the bridge to see.

It lives in the ringtone plugin package for the ringtone's reason: a plugin
package is registered into every engine.

## Answering a dead call must not raise a second ringing screen

The other half of the same report, and the reason it looked like two incoming
screens. A stale lock-screen surface can be answered by hand, and that Accept
reaches Dart as an ordinary CallKit event. `acceptIncoming` used to publish
`incomingRinging` the moment its `GET` returned — before checking the status —
so `CallStoreSync` opened `/call` and `ensureNativeIncomingUi` started the
in-app tone for a call that had ended minutes ago. The not-ringing guard below
it then called `_endNative` and returned, which closes CallKit and leaves this
notifier exactly where it stood: a ringing screen with Accept and Decline and
no event left in the world to dismiss it.

`isVoiceCallRingable` (`voice_call_ringable.dart`, unit-tested) now gates that
state transition, and the guard finishes locally (`_finishLocal`) instead of
only dismissing the native surface. The rule behind both: **the server row is
the only authority on whether a ringing surface is allowed** — a push and a
CallKit record both outlive the call they announce.

## A CallKit decline names a call the provider may not know

`declineIncoming` / `_finishLocal` work from the **passed call id**, never from
`state.call` alone. A Decline pressed on the CallKit full-screen UI or in the
notification shade usually arrives for a call `VoiceCallNotifier` never loaded:
the push was handled while the app sat in the background, so the ringing state
lives only in CallKit. Reading `state.call?.id` there yielded `null`, which
skipped `_endNative` entirely — the native record survived, the `native` ring
holder was never released, **the tone kept playing**, and resuming the app let
`_recoverNativeCall` find the record and ring all over again on the in-app
screen (fixed 2026-08-26). `_rememberFinished(id)` runs before anything else
for the same reason, and a decline that lands while `_transitioning` still
dismisses the native surface.

`CallEventActionCallEnded` for an unknown call is treated as a decline
(`_declineUnknownNative`) — otherwise the caller hears ringing until the
server's sweeper expires it.

## A killed app drops CallKit events unless the executor is booted

`FlutterCallkitIncomingPlugin.send` delivers a call event to a listening
Flutter UI engine, else to `CallkitBackgroundExecutor` — **but only if that
executor is already running**, and the only thing that starts it is
`FlutterCallkitIncoming.onBackgroundMessage`, called from `main()`.

A phone whose app is killed rings from the **FCM background isolate**, where
`main()` never ran. So Decline on the CallKit full-screen screen (or its
notification action) reached nothing at all: the tone played until the 70 s
backstop, the decline was never POSTed, and opening the app found the call
still ringing server-side. Two fixes, both required:

- `main.dart` registers the CallKit background handler **inside** the FCM
  background handler, before raising the ringing UI, so the executor is up
  before any event can arrive.
- `CallEventBridge.kt` (installed by `AbabilXApplication`, so it exists in
  every process however it started) releases the ring natively and boots the
  executor from the handle stored in the plugin's prefs, as the backstop for a
  process that reached the broadcast some other way.

Symptom to recognise: Decline does nothing, ring continues, and the in-app
screen is ringing when the app is opened — while Decline from inside the app
works fine.

## Native ring stopper (belt and braces)

`CallEventBridge` (a Kotlin `object`, installed from `AbabilXApplication`)
registers a `CallkitEventCallback` with `FlutterCallkitIncomingPlugin`;
`CallkitIncomingBroadcastReceiver` invokes it straight from the broadcast on
ACCEPT / DECLINE / END, so the `native` hold is released without waiting for
the event to reach Dart. It only releases the ring — Dart still owns ending the
call. It lives in the Application, not the Activity, because the processes that
need it most have no Activity; the plugin keeps a `WeakReference`, which is why
it is a static `object` rather than a field.

## The connected call has a surface even when no screen is open

Added 2026-08-26, after "someone calls me, I answer, I press back, and now I
cannot get back to the call or end it".

`AndroidCallUi.hideIncoming` deliberately tears the CallKit surface down the
moment a call is answered, so the Flutter `/call` screen is the only ringing
UI. Nothing then replaced it for the _connected_ phase, and `/call` is an
ordinary route with no `PopScope` — so back popped it and left a live WebRTC
session with no way in and no way out. The call ran until the peer hung up or
the server sweeper expired it.

Two surfaces now cover that, both Signal's:

- `OngoingCallService` + `OngoingCallNotification` (Kotlin) — an ongoing
  `CallStyle.forOngoingCall` entry on its own `call_ongoing` channel (DEFAULT
  importance, silenced; it was Signal's LOW `call_status` until 2026-09-10 —
  see "A call answered on a locked phone" below). Tap the body to return,
  press Hang up to end it from the shade.
  Shaped after `CallNotificationBuilder.TYPE_ESTABLISHED`; it never makes a
  sound, because ringing is a different surface and belongs to CallKit +
  `call_ringer`.
- `ActiveCallBanner` + `CallReturnBar` — the in-app bar for the commoner case,
  where the user minimised the call but is still inside AbabilX. It carries the
  peer's name and the **live** status, not a fixed "tap to return": the same
  `voiceCallStatusText` the call screen and the PiP window show, so the three
  can never disagree. The bar ticks its own one-second clock (a running
  duration is not a state change, so the parent would not rebuild for it) and
  turns `colorScheme.error` while a recovery is in progress. A group call shows
  the participant count instead of a duration — `GroupCall.startedAt` is when
  _someone_ started the call, not when this device joined, and a wrong timer is
  worse than a right count.
  **`MediaQuery.removePadding(removeTop: true)` on the screen under the bar is
  load-bearing.** The bar's own `SafeArea` takes the status-bar inset so it
  tints that strip the way WhatsApp does; the screen below sits in the same
  MediaQuery and would otherwise apply the inset a second time, pushing every
  header down by a whole status bar. That was the "too much space at the top"
  report.

`OngoingCallSync` owns both: it mirrors `voiceCallProvider` / `groupCallProvider`
onto the notification and routes the two presses back. The DM call wins when
both somehow exist — it is the one whose audio is live.

`OngoingCallChannel` is **Activity-scoped**, unlike `call_ringer`, and that is
correct rather than an oversight: a connected call lives in the Flutter
isolate, so an engine that is gone means a call that is already over. A
ringtone has the opposite requirement — see the plugin-package section above.

## There is exactly one ongoing-call notification, and it is ours

Fixed 2026-09-04, from "I press hang up in the notification panel and the call
does not close".

`flutter_callkit_incoming` posts its **own** ongoing-call notification, with its
own Hang up button, and it does so by default — `isShowCallingNotification`
starts `true`, and `ACTION_CALL_ACCEPT` / `ACTION_CALL_CONNECTED` both raise it
(via a second foreground service, `CallkitNotificationService`). So a connected
call put two "on a call" entries in the shade, and the one the user reached for
was as likely to be the plugin's as ours.

`AndroidCallParams` (both incoming and outgoing) and `_ongoingParams` for group
calls now pass `callingNotification: NotificationParams(showNotification: false)`.
That kills the notification _and_ the plugin's foreground service — CallKit
still keeps its call record, which `_recoverNativeCall` and `_adoptNativeAccept`
depend on. `OngoingCallService` is the single entry.

Because the plugin's "Calling…" entry went with it, `OngoingCallSync` now covers
`outgoingRinging` and `connecting` as well as `connected`
(`ongoingCallSubtitle`, unit-tested). `connected` is threaded down to
`setUsesChronometer` — a timer beside "Calling…" reads as a call already in
progress.

**`OngoingCallSync` drives off `ref.listenManual`, not `ref.watch` in `build`.**
This is the other half of the same report. The sync used to run from a
post-frame callback, and **a backgrounded Flutter app schedules no frames** — so
hanging up from the shade tore the call down correctly and then left its
notification sitting in the tray until the user next opened the app, which
reads exactly like the press having done nothing. Anything that has to react
while the app is in the background belongs on a listener, never on a frame.

## The notification must not outlive the engine that posted it

Fixed 2026-09-09, from "I home the app, the shade says the call is running, but
back in the app there is no call bar and I cannot reach the call screen".

The call lives in the FlutterEngine, which the **Activity** owns.
`OngoingCallService` does not — it is a foreground service in a process that
survives its Activity. So when Android reclaims the Activity while a call is up
("Don't keep activities", memory pressure), the WebRTC session dies with the
engine and the notification stays behind, describing a call nothing in the app
knows about. Every surface then disagrees: no `ActiveCallBanner` (the provider
is at `idle`), no `/call` route to open, and the notification's tap lands in
`OngoingCallSync` which had nothing to return to.

`stopWithTask="true"` does not cover it — that is the task being swiped away,
which is a different event.

Three pieces, and they are all needed because each fails alone:

- **`MainActivity.onDestroy` stops the service.** The engine is dying, so the
  call is dying; the tray entry has to go with it.
- **`AndroidOngoingCall.stop(force: true)`.** `_running` is per-isolate state,
  so a _fresh_ engine believes it has posted nothing and the ordinary `stop()`
  returns before it sends anything. Force is the only way a new engine can take
  down an entry an old one raised.
- **`OngoingCallSync` clears once on boot** (`_clearedOrphan`). Its `_shownKey`
  is empty at start, and the early return on an empty key meant a stale entry
  was never even considered. The first sync with no call now always sends the
  stop; after that the key check takes over and nothing is re-sent per state
  change.

The tap itself is also handled: `returnToCall` with neither provider active
takes the notification down instead of opening a call screen with no call
behind it.

What this does **not** do is save the call — the media died with the engine and
cannot be recovered. The server's own row is cleaned up by the heartbeat sweep
(2 minutes), and a user who calls again before then gets `voice_call_busy_self`,
which `activeCall()` already recovers from.

## A CallKit Accept can arrive as a fact, not as an event

Fixed 2026-09-04, from "I accept from the full-screen call notification and the
app opens another full-screen caller screen where I have to accept again".

The app was already holding `incomingRinging` (from the `call.incoming`
websocket event) while backgrounded. Accept on the CallKit surface brings the
Activity forward, but the plugin does not replay the event it emitted to a
paused engine. `CallStoreSync` then ran its resume path:

```
syncFromNativeIncoming()   // state.active is TRUE for a ringing call,
  -> resyncActiveCall()    // ...which only fixes outgoingRinging -> accepted
ensureNativeIncomingUi()   // Flutter is focused now: take the ringing UI back
```

— so the CallKit surface was dismissed and replaced with the in-app one, still
asking to be answered. The `isAccepted` check that would have caught it lived
in `_recoverNativeCall`, which that first branch skips.

`syncFromNativeIncoming` now tries `_adoptNativeAccept` first: if CallKit's
persisted record for the call in state says `isAccepted`, apply the accept
instead of re-showing the ring. The predicate is `nativeCallWasAccepted`
(`native/incoming_call_admission.dart`, unit-tested). It returns true when an
accept is merely _in flight_ too — the point of the return value is "do not put
the ringing UI back up", not "the call is connected".

## Back on a DM call goes to the chat list — PiP is for group calls only

Rewritten 2026-09-04. The DM call screen used to shrink into a floating window
on back and on the minimise chevron. That is Signal's move, and it is wrong
here: Signal's call owns its own Activity, ours is the one FlutterActivity for
the whole app, so "minimise the call" shrank **the entire app** into a
thumbnail — and `ActiveCallBanner` never got a chance to show, because the
route was still `/call`.

WhatsApp's split is the one we follow now, and it matches what each call
actually needs:

- **DM voice call** — back and the chevron both run `popOrGoHome`, so the user
  lands back where they were with the return bar across the top. No PiP is
  armed at all, which also means Home just backgrounds the app (the ongoing
  notification is the surface there) instead of shrinking it.
- **Group call** — still shrinks. There are video tiles and a screen share to
  keep watching, which is the case a thumbnail is actually for.

`AndroidPip.setActive` is therefore called by `GroupCallScreen` only, and
native `enter()` refuses when it is off — otherwise Home on the chat list would
shrink the whole app.

- Armed by the group call screen only. **Never for an incoming call**: a
  thumbnail has nowhere to put Answer, and Signal does not shrink one either.
- API 31+ gets `setAutoEnterEnabled(true)` so the system animates the Home
  transition itself; older versions fall back to `onUserLeaveHint`.
- `AndroidPip.inPip` drives a compact layout (`PipCallView`) — name, status,
  and nothing else. No controls: the window is too small to hit them, and
  tapping it restores the screen where they live.
- Both screens keep `canPop: false` while the call is live and act in
  `onPopInvokedWithResult`, so the DM screen's pop runs through `popOrGoHome`
  — a plain `Navigator.pop` on a route reached straight from a push has no
  history to return to and would strand the user on a blank screen.
- Manifest: `MainActivity` carries `supportsPictureInPicture` and
  `resizeableActivity`. Its `configChanges` already lists the size/orientation
  keys PiP needs, so the Activity is resized rather than recreated.

## The display belongs to the call

Added 2026-09-04, for "the screen stays lit against my ear".

Nothing turned the panel off when the phone was held to the face: the display
burned battery and took Mute / Speaker / Hang up presses from a cheek. Two
separate locks fix it, both from Signal's `LockManager`, both in
`CallScreenLock.kt` behind `com.ababilx.app/call_screen_lock`:

- **`PROXIMITY_SCREEN_OFF_WAKE_LOCK`** — the system's own answer, so the sensor
  decides when the panel is off and nothing here has to poll. Held only while
  a call is **connected** and **on the earpiece**: a ringing call is one the
  user is looking at, and speakerphone means the phone is nowhere near a face.
  Signal engages proximity in `IN_CALL` and nowhere else; `_syncProximity` in
  `OngoingCallSync` is the same rule.
- **`FLAG_KEEP_SCREEN_ON`** — otherwise the display sleeps on the system
  timeout mid-call and the user has to unlock the phone to hang up.

Two calls, not one flag, because the lifetimes differ: proximity follows the
**call** (the phone is still at the ear after backing out to the chat list),
keep-screen-on follows the **call screen** (`VoiceCallScreen` /
`GroupCallScreen` init/dispose), because keeping the display awake while
someone reads messages is a battery bug.

Traps:

- **Headsets are checked natively, not in Dart.** `speaker == false` does not
  mean earpiece — a wired or Bluetooth headset is also "not speaker", and the
  phone is then in a pocket. `CallScreenLock` registers an `AudioDeviceCallback`
  while the lock is wanted and drops it the moment a headset appears, so this
  corrects itself mid-call without Dart noticing.
- **Release with `RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY`.** A plain release when
  the call ends while the phone is still at the ear flashes the screen on
  inside a pocket. The flag holds it dark until the phone comes away.
- The wake lock is acquired with no timeout on purpose (a call has no bounded
  length) and released explicitly — including from `MainActivity.onDestroy`,
  or a lock would outlive the call that justified it.
- Activity-scoped, like `OngoingCallChannel` and for the same reason: a
  connected call lives in the Flutter isolate.

## The 1:1 call screens are a wallpaper + glass overlay

`IncomingCallView` and `ConnectedCallBody` share one design language:

- **Audio-only:** theme wallpaper (`call_light.jpg` / `call_dark.jpg`) fills
  the window. The UI is a transparent overlay — circular peer face (~30% down),
  name + status, frosted glass controls, and a coral End / Decline.
- **Video / screen share:** remote media is full-bleed; wallpaper is not drawn;
  the same glass controls sit on top, then **auto-hide after ~4 s idle**
  (`CallChromeAutoHide`) so the stage is clear. Tap the empty stage to show
  or hide chrome again. Local camera PiP stays visible while chrome is hidden.
  Audio-only never auto-hides — Mute / End must stay reachable without a tap.
- **Minimize:** a small chevron in the top-left safe area leaves the screen
  without hanging up (`ActiveCallBanner` / return bar takes over).
- **Incoming** keeps only Answer + Decline (no Mute/Camera/Share yet) — large
  paired circles centered with a comfortable gap (`incomingActionGap`), not
  `spaceBetween` to the screen edges.
  **Outgoing / connected** uses Mute · Camera · Screen Share · Speaker + End.
- Labels: Incoming hang-up says **Decline**; live hang-up says **End**.
  Captions hide in landscape; semantics keep the names.

**Native overlay when the app is closed** is a separate surface:
`CallkitIncomingActivity` (`flutter_callkit_incoming`), raised by the
notification `fullScreenIntent`. Flutter hot reload does not touch it.
Layout/dimens are pinned under `android/patches/callkit/` and applied by
`patches/callkit-incoming-ui.gradle` (avatar 160dp, buttons 100dp, centered
gap, bottom lift). Keep view ids; Accept/Decline wiring stays in the Activity.
After a plugin bump, re-copy and re-check the Activity margin patch.

Group call UI is separate (`GroupCallScreen`) — participant tiles need a
different layout.

Do not restore the old Signal-blurred-avatar backdrop on the DM call surface
without an explicit product decision; PiP is unchanged.

### Control deck orientation — pin to portrait-bottom, never the camera bump

Owned by `CallControlsAnchor` + `CallControlsRow`
(`pinControlsToPhysicalBottom`).

**Portrait**

- Deck sits on the **bottom** safe inset (home / gesture edge).
- Four toggles in one row; **End** drops under them (`AnimatedSize`).

**Landscape**

- Same physical edge as portrait-bottom becomes a **vertical strip** on the
  left or right — **not** the landscape screen’s bottom bar, and **not** the
  camera / notch / Dynamic Island edge.
- All five seats (Mute · Camera · Screen Share · Speaker · End) share that
  one strip (End inline). Seat diameter shrinks to fit the short edge.
- Circle chrome stays put; only glyphs may turn via `CallIconOrientation`
  (do **not** `RotatedBox` the whole deck — that moved seats and confused
  “icon-only rotate”).

**Which side in landscape (easy to get backwards)**

| You rotate phone… | Portrait-bottom becomes… | Strip pins… |
| ----------------- | ------------------------ | ----------- |
| Left (CCW)        | Right edge of the view   | **Right**   |
| Right (CW)        | Left edge of the view    | **Left**    |

Implementation rule: the camera/notch cutout makes the **larger** horizontal
`viewPadding`. The home/gesture edge (portrait controls) has the **smaller**
inset — pin there (`viewPadding.right <= viewPadding.left` → pin right).
Equal insets → default pin right (rotate-left case).

**Do not**

- Pin to `padding.right >= padding.left` (that prefers the **notch** and
  sends the deck to the camera bump — already shipped as a bug once).
- Drop the landscape deck onto the bottom of the landscape frame “for
  simplicity”.
- Rotate the entire control column with `RotatedBox` when you only meant
  glyphs to follow gravity.

Tests that lock this: `caller_controls_layout_test.dart` (notch-left →
strip right; notch-right → strip left).

## Screen sharing rides the call's own service — never a second one

`AndroidScreenShare` used to stand up its own foreground service, borrowing
flutter_local_notifications' generic `ForegroundService` and pinning it in the
manifest to `foregroundServiceType="mediaProjection"` app-wide. A shared call
therefore ran two independent foreground services, with the MediaProjection's
lifetime owned by flutter_webrtc and the service's lifetime owned by a
notification plugin, and nothing sequencing their teardown. Ending a call while
sharing raced them, and Android 14+ is strict about that pairing.

Signal runs **one** service for the whole call and ORs the projection type in
and out of the mask (`ActiveCallForegroundService.serviceType`). So does
`OngoingCallService.serviceType()`: `MICROPHONE`, plus `MEDIA_PROJECTION` while
`screenSharing`. `AndroidScreenShare.start/stop` is now a thin call into
`AndroidOngoingCall.setScreenSharing`, which starts the service if a call never
registered one — the projection type must be in place _before_ capture begins.

Do not add a second foreground service for capture. If a new capture surface
needs a type, add it to that mask.

## A dropped media path is restarted, not hung up

Added 2026-09-04, for "long calls die when I walk around".

`VoicePeerEngine` used to end the call 12 s after `RTCPeerConnectionState
Disconnected`, and immediately on `Failed`. Neither state recovers on its own —
the candidate pair carrying media is gone — so every WiFi-to-mobile handover,
lift, tunnel and carrier IP reassignment killed a live call. The longer the
call, the likelier one of them fires.

The engine now only _reports_ those transitions (`onTrouble`), and
`VoiceReconnectController` decides what to do: run an ICE restart, back off,
and keep trying for `VoiceReconnectPolicy.giveUpAfter` (120 s) before failing.
`onHealthy` fires on every entry to `connected`, not just the first, and is
what cancels a recovery.

Rules that are load-bearing:

- **Only the original caller re-offers.** `restartIce()` arms libwebrtc's flag;
  the next `createOffer` carries the new ufrag/pwd. Two simultaneous restart
  offers are glare and neither applies, so a callee that notices first sends
  the payload-less `{"kind":"restart"}` signal and lets the caller do it.
  `services/voicecall/signal.go` whitelists that kind — an older server rejects
  it, which degrades to today's behaviour rather than breaking.
- **Recovery starts only after the call has connected once**
  (`state.connectedAt != null`). Before that `_startConnectWatchdog` owns the
  timeout and a restart would race the first offer/answer.
- **The phase stays `connected` during recovery**; only `state.reconnecting`
  flips. A new phase would tear down the ongoing-call notification, the audio
  route and the call screen — all of which must survive. `voiceCallStatusText`
  shows "Reconnecting…" instead of a frozen timer.
- **`connectivity_plus`'s first event is the current network, not a change.**
  Acting on it restarts a healthy call the instant it connects, so the
  controller seeds a baseline (`_seedNetwork`) and ignores no-op transitions.
  Going _offline_ is deliberately not actionable: there is nothing to restart
  onto. Coming back resets the recovery budget, or an outage longer than
  `giveUpAfter` would kill the call exactly when it became recoverable.
- **A hard deadline runs beside the attempt chain.** An attempt that hangs (a
  socket connect that never returns on a dead network) would otherwise leave
  "Reconnecting…" on screen with nothing left to end it.
- **Attempts never overlap, and carry a generation.** `_schedule` cancels the
  pending _timer_, not an attempt already awaiting a TURN fetch — so a
  connectivity event mid-fetch used to start a second attempt whose older
  credentials could land _after_ the newer ones. `_attemptInFlight` queues
  instead, `_generation` invalidates a late completion, and the provider's
  `_restartStillWanted` re-checks engine **identity** (not just the call id)
  after every await. Stale async completion is the classic failure of a
  reconnect loop; both sides of the boundary guard against it.
- **The wording softens, the deadline does not.** Two minutes of an unchanging
  "Reconnecting…" reads as a hung app, so `voiceReconnectText` moves through
  "Reconnecting…" → "Poor connection. Still trying…" → "Connection lost.
  Trying to restore…" at 15 s and 45 s. Text only — the audio route, the
  notification and the recovery budget are untouched. `state.reconnectingSince`
  is the instant, and `state.reconnecting` derives from it, so the two can
  never disagree.
- **Each attempt re-fetches ICE servers** and calls `applyIceServers`
  (`setConfiguration`). coturn REST credentials are timestamped, so a call
  outliving its credential loses the relay on the next allocation refresh —
  which is also why `turnCredentialTTL` defaults to 12 h server-side, not 60 m.
  The re-fetch doubles as the "peer's app died without sending call.ended"
  check: a terminal status ends the call instead of burning the whole budget.
- **Dispose the controller wherever the engine is disposed** — it holds a live
  connectivity subscription and two timers. Both `_finishLocal` and
  `_resetResources` do.

Group calls need none of this: LiveKit reconnects its own `Room`.

Files that change together: `webrtc/voice_reconnect_controller.dart`,
`webrtc/voice_reconnect_policy.dart`, `webrtc/voice_peer_engine.dart`,
`providers/voice_call_provider.dart`, `providers/voice_call_state.dart`,
`call_status_text.dart`, and server-side `services/voicecall/signal.go` +
`ice.go`.

## Call audio routing — speaker vs earpiece

`livekit_client`'s Android plugin runs
`AudioSwitchManager.setAudioSessionManagementEnabled(false)` in
`onAttachedToEngine` (`LiveKitPlugin.kt`), at app start, process-wide. Every
flutter_webrtc audio call is a **no-op** from then on: `setSpeakerphoneOn`,
`selectAudioOutput`, `setAndroidAudioConfiguration`, session start. That is why
the Speaker button did nothing and DM calls always came out of the earpiece.

`audio/call_audio_route.dart` is the fix and the only place a DM call may touch
audio routing:

- `activate(speaker:)` — before `getUserMedia` in `VoicePeerEngine.prepare`;
  applies LiveKit's communication session (`MODE_IN_COMMUNICATION`, focus,
  `STREAM_VOICE_CALL`, `forceAudioRouting: true`) and the starting route. That
  route is the **earpiece** (changed 2026-09-04 from an "audible default" of
  speaker): a call answered and lifted to the ear must not come out of the
  loudspeaker, and proximity blanking keys off the same flag. `prepare` mirrors
  it into `state.speaker` explicitly rather than trusting the default, because
  an earlier call in the same session may have left it on.
- `setSpeaker(on)` — the Speaker button; `force: on` so an explicit press wins
  over a connected headset.
- `release()` — on engine dispose; drops focus and restores the normal mode.
  Leaves LiveKit in **manual** mode, because handing management back would
  re-activate the session that was just released.
- `restoreForRoom()` — called before a group `Room` connects, the other half of
  that contract.

Group calls need none of that: a LiveKit `Room` configures the session itself.

**A call Android Telecom is hosting is routed through Telecom** (2026-09-10,
"Speaker does nothing on a call I answered from the lock screen").
flutter_callkit_incoming registers every ring it shows as a self-managed
Telecom call, and Answer on its screen (lock screen, heads-up) marks it active.
Telecom then sets `MODE_IN_COMMUNICATION` itself — `dumpsys audio` shows
`com.android.server.telecom` setting the mode — and a privileged caller is
always the mode owner; AudioService applies the mode owner's communication
route and nobody else's, so LiveKit's request from this app was dropped with
no error. The plugin's own `setAudioRoute` method is an empty stub.

- `CallAudioTelecom.kt` (`com.ababilx.app/call_audio_telecom`) finds the
  plugin's `CallkitConnection` for the call id and, only while it is ACTIVE,
  calls `Connection.setAudioRoute`: speaker, else Bluetooth when Telecom lists
  it, else wired-or-earpiece — where LiveKit would go. It is deprecated on 34
  for `requestCallEndpointChange`, which needs endpoint callbacks only the
  plugin's `Connection` subclass receives; `setAudioRoute` still reaches
  Telecom's router.
- `TelecomAudioRoute.route` answers false for anything Telecom is not
  hosting — a call answered in the app (its Telecom call stays RINGING), placed
  from it, or not Android — and then LiveKit's route is the one that counts.
  `CallAudioRoute.setSpeaker` asks Telecom first and still sets LiveKit's
  preference, so the two agree if Telecom lets go.
- The DM call id is bound once in `_prepareEngine` (`CallAudioRoute.bindCall`);
  group calls pass theirs to `CallAudioRoute.preferRoomSpeaker`, which is also
  how a group's speaker-on default survives a lock-screen join.
- Emulator proof, logged by `locked_call_harness.dart`: ringing → not handled,
  accepted → handled. The emulator has no earpiece, so hearing the switch
  still needs a real phone.

iOS still routes through `Helper.setSpeakerphoneOn` — LiveKit only disables
flutter_webrtc's manager on Android and macOS.

## Ringtone device test (emulators do not prove this)

Background the app, call, let it ring 30 s+. Repeat locked, repeat with the app
killed, repeat while changing volume and with an OEM increasing-ring ramp on.

```bash
adb logcat -s CallRinger:V CallRingerPlugin:V flutter:V
```

## The group call screen is a lobby, a stage and a roster

Rebuilt 2026-09-07, desktop first (`ababilxdesktopcode`), then here. Nothing
about the transport moved: same LiveKit `Room`, same four endpoints, still
audio plus one screen share. The write-up that covers both platforms is in the
monorepo root `CLAUDE.md`; what follows is what only matters on the phone.

```
features/calls/group/
  signals/call_signals.dart        wire codec, byte-shared with web
  providers/group_call_signals.dart   hands + reactions over the data channel
  providers/group_call_lobby.dart     the pre-join phase (no server side)
  call_icons.dart                  hugeicons glyphs + the CallIcon wrapper
  call-ui/                         surface, tiles, stage, header, roster, bursts
  screens/group_call_lobby_screen.dart
  screens/group_call_screen.dart
```

- **`GroupCallSync` owns every route change, lobby included.** The lobby screen
  and the call screen navigate nowhere themselves — two owners would race, and
  lobby → call has to be a `pushReplacement` or leaving the call pops back into
  the lobby it came from. Cancelling the lobby only clears the phase; the sync
  pops the route.
- **The lobby asks for the microphone, and that is the point of asking there**:
  before anybody can hear whether the answer was no. `FcmBootstrap` still asks
  once at first launch, so this is usually a status read, not a prompt. There
  is no level meter — `livekit_client` exposes no pre-join capture and faking a
  bar that moves for nothing would be worse than showing none.
- **PiP, the ongoing-call foreground service and the display locks are
  untouched.** `AndroidPip.setActive` is still armed by the call screen only
  (never the lobby: there is no call to shrink), and back still shrinks rather
  than leaving a live room with nothing on screen.
- **Hugeicons are path data, not `IconData`.** `CallIcons` are `CallGlyph`
  (`List<List<dynamic>>`) and must go through `CallIcon`, never `Icon`. The
  chat-header pill still takes a Material `IconData` because it is shared with
  the DM call action.
- **The group call follows the theme; the DM call uses theme wallpapers.**
  Group colours come from `CallColors.of(context)`. The 1:1 audio surface
  picks `call_light.jpg` / `call_dark.jpg` from brightness; glass controls and
  white labels stay fixed so they read on both wallpapers and over video.
  Do not "restore" a permanently dark blurred-avatar backdrop without a
  product decision.

### The stage divides the space it has; the control bar divides its width

Four layout bugs shipped together in the rebuild and all four came from a
widget being allowed to size itself:

- **The control bar was a `Wrap` of fixed 58dp buttons.** Seven controls need
  `7x58 + 6x12 = 478dp`; a 412dp phone has 388 after padding, so it broke 5 + 2
  and left **Hang up orphaned in the second row beside Participants**.
  `CallControlBar` divides the width it is actually given and shrinks the
  buttons (floor 36dp, then it scrolls). Participants is gone from the bar
  entirely — the header already carries it, and that duplicate was the seventh
  control. Speaker routing (earpiece / loudspeaker) lives in the header beside
  Participants too — device routing, not an in-call action — so the connected
  bar is five: Mute · Share · Hand · React · Leave.
- **Fitting on one row was not the same as looking like a bar.** The fixed
  buttons then spanned the screen edge to edge over the bare backdrop, and the
  disconnected state drew Hang up as a lone 58dp circle in the middle of
  nothing. `CallControlBar` draws one rounded pill (`palette.panel`) behind the
  row with 8dp of inner padding, and the pill hugs its contents, so a single
  control comes out as a small rounded button rather than a floating circle.
  The controls divide the width **inside** that padding — dividing the full
  width first overflows the pill by exactly `2 x padding`. Standard diameter
  came down 58 → 50 to leave room for the pill and a margin either side of it.
- **`GridView` with a fixed `childAspectRatio` sizes rows from the tile width
  and stops.** A solo call drew one screen-wide tile 1.11x as tall and left
  ~185dp of dead black beneath it. `CallTileGrid` derives the tile height from
  the stage height, and lays rows out by hand so a short final row centres.
- **`Row` and `Column` default to `crossAxisAlignment: center`.** A tile draws
  its own background and sizes to its content, so every tile collapsed to
  content size — zero height in the grid, avatar width in speaker view. All
  three stage axes are `stretch`. A layout test catches this; the eye does not,
  because a centred half-size tile still looks deliberate.
- **The avatar was a `CallTileSize` enum defaulting to 62dp and the grid never
  passed anything else**, so a solo call put a 62dp speck in a screen-wide
  tile. It is derived from the tile's own box now (`0.40` of the shortest side,
  clamped 36-128) and the enum is gone, which is what stops the next caller
  forgetting to override it.
- **A `Positioned` with both `left` and `right` set hands its child a tight
  width.** The name "chip" therefore stretched the tile edge to edge and read
  as a disabled text field. It is wrapped in an `Align` now.

Hang up is `CallButtonTone.danger`, and that pair is chosen per brightness in
`CallColors`: M3's `error` is a strong red in light and a pale pink in dark,
`errorContainer` the reverse, so neither alone stays red in both themes. Using
`error` as a fill in dark is what drew the pale pink circle with the dark red
glyph.

Pinned by `test/features/calls/group_call_layout_test.dart` (stage) and
`group_call_control_bar_test.dart` (bar) — these are all
constraint bugs, which unit tests cannot see and screenshots only catch if
somebody happens to look at the right participant count.

## `currentConfiguration.uri` is not the route you are on

`GroupCallSync` owns every `/group-call` route change and asks "am I on it?"
before pushing or popping. It asked `routerDelegate.currentConfiguration.uri.path`,
and that is wrong for a pushed route: `RouteMatchList.push` appends an
`ImperativeRouteMatch` through `copyWith(matches: …)` and carries the base
`uri` over untouched. After `push('/group-call')` from a chat the location
still reads `/messages/<id>`.

Everything downstream of that guard was therefore dead:

- **Leave never left.** `_leaveCallScreen` bails unless the path is
  `/group-call`, so hanging up only emptied the state and the screen stayed —
  header with no duration, "Waiting for others to join…", and a hang-up button
  for a call that had already ended. That page was not a state anyone designed;
  it was the call screen that failed to pop.
- The dedupe in `_openCallScreen` never matched either, so two pushes of the
  same route were possible and only one of them would ever be popped.
- `ActiveCallBanner` hides itself on the call route by the same comparison, so
  the "return to call" bar drew across the top of the call it was offering to
  return to.

`currentRoutePath` (`core/router/router_path.dart`) reads
`currentConfiguration.last.matchedLocation`, which `push` does update, and is
now the only way any of this is asked. `CallStoreSync` navigates with `go`, so
the DM side never showed the bug — it is on the helper anyway, because the next
person to switch a `go` to a `push` should not have to rediscover this.
`test/core/router/router_path_test.dart` pins both halves, including the
assertion that `uri.path` still reports the old location.

## `ActiveCallBanner` must never change the shape of its subtree

Its `child` is go_router's `_CustomNavigator`, keyed by
`GlobalObjectKey(navigatorKey.hashCode)` (`go_router/src/builder.dart`). The
banner used to return that child bare when no call was running and wrap it in
`Column > Expanded > MediaQuery` when one was, which moves a GlobalKey between
parents — in the same frame the router is rebuilding its match list, because
both are driven by the call ending. On device that is:

```
Duplicate GlobalKey detected in widget tree
_CustomNavigator-[GlobalObjectKey int#…] must not be deactivated when in
  _ElementLifecycle.failed state
'!_dirty': is not true            '_elements.contains(element)': is not true
```

right after `onConnectionChangeDISCONNECTED`. The slot is now always occupied —
by the bar, or by a `SizedBox.shrink()` — and `MediaQuery.removePadding` is
always present with `removeTop: show`. **An `if (show)` in the children list is
the same bug more quietly**: it shifts the `Expanded` from index 1 to index 0,
and a multi-child widget matches children by index, so the navigator is
reparented again.

`test/features/calls/active_call_banner_test.dart` asserts the _shape_, not the
state: a GlobalKey preserves its `State` across a reparent, so an assertion on
the State passes either way — the first version of this test did, which is
worth remembering before writing another one like it.

## Leaving the call screen is not leaving the app

The chevron and Back return to the app and leave the call running behind
`ActiveCallBanner`; they do not shrink into a floating window. Reaching for a
control _inside_ the app should not eject the whole app into a thumbnail over
the launcher. PiP is still armed the whole time the call screen is mounted
(`AndroidPip.setActive`, which sets `setAutoEnterEnabled` / `onUserLeaveHint`),
so pressing Home shrinks the call exactly as before — that is the case PiP is
for. Nothing is lost by popping, because the call was never the route: the
banner, the ongoing notification and the channel header all lead back to it.

## Answering here has to silence every other device

One account, several signed-in devices, all of them ringing. When one picks up,
the other ring surfaces have to come down, and they learn about it two ways: the
WebSocket `call.accepted` / `group_call.self_joined` for a device whose app is
alive, and an FCM control push (`voice_call_answered`, `group_call_joined`) for
one that is killed or dozing and is ringing from the push alone.

**The push is addressed to the account, not to a device** — FCM cannot address
a device — so it also lands on the phone that just answered. Everything below
exists to keep that phone's live call from being torn down by the message that
announces it:

- `decideAnsweredElsewhere` (`native/answered_elsewhere.dart`) is the single
  rule, pinned by `test/features/calls/answered_elsewhere_test.dart`. Three
  places act on these pushes and they must agree.
- In the foreground the answer comes from **live call state** — a DM in
  `connecting`/`connected`, a group call this device is in. In the background
  isolate there is no state, so `CallAnsweredGuard` (a durable secure-storage
  mark written on accept and on join) stands in for it.
- **`FcmService` swallows both control types on purpose.** Both call providers
  subscribe to the same `onMessage` stream and hold the state that separates
  the answerer from a bystander; a second handler acting off the durable mark
  alone would race the write and could dismiss the answerer's own surface.
- **Never route these through `VoiceCallEndedGuard.markEnded`.** Answering is
  not terminal. That mark is what suppresses a later `incoming`, and the call it
  describes is still very much running.

## Video calls (2026-09-08)

A video call is the voice call with a camera track — same `VoicePeerEngine`,
same signalling, still peer-to-peer. The parts that are not obvious:

- `webrtc/voice_camera_capture.dart` opens the camera as its **own**
  MediaStream, separate from the microphone stream. That gives the track its
  own `msid`, which is the only thing that lets the far side tell a camera
  from a shared screen.
- `webrtc/voice_media_map.dart` is the receiver half: a `media` signal
  (`camera_stream`, `screen_stream`) arrives before the offer/answer and
  `onTrack` is routed by stream id. No map ever = legacy peer = screen share.
- **Open the camera before the first offer/answer** (`prepare(video: true)`),
  never on `connected`: both sides re-offering at once is glare, and the
  losing offer is silently dropped.
- **On/off after the first add is `replaceTrack`**, so no renegotiation and
  no glare. The map names `_cameraWireStreamId` — the id the far side learned
  at `addTrack` — not the new capture's id.
- The camera pauses (`setCameraPaused`) on `paused`/`hidden`/`detached` via
  `CallStoreSync.didChangeAppLifecycleState` → `onAppLifecycle`. There is no
  camera foreground-service type in the manifest, on purpose.
- Camera permission refused = audio call, not a failed call.
  `_ensureCameraPermission` never throws; only the in-call toggle reports it.
- **The callee never offers.** `_renegotiate` on the non-offerer sends
  `{"kind":"renegotiate"}` and the caller re-offers. flutter_webrtc has no SDP
  rollback, so a peer holding its own offer can never apply an incoming one:
  glare is unrecoverable here and the fix is to make it impossible. A colliding
  offer that still arrives (old peer) is ignored, not applied. There is a 4 s
  fallback to offering directly, for a server that predates the signal.
- **A signal-handling error does not end a connected call** any more; it goes
  to `VoiceReconnectController`. That single `_failLocal` was why a bad SDP
  dropped the call on both phones at once.
- **`VoiceCallHeartbeat` beats every 20 s while accepted.** Without it a call
  whose network died stayed `accepted` on the server forever and both accounts
  were refused every later call as busy. The reply carries the row, so a phone
  that was swept learns it here.
- **Camera capture is bounded (720p30) and the sender capped at 800 kbps**
  (`voice_video_quality.dart`). It had minimums only, so devices captured
  1080p, and a relayed call could not carry it.
- Layout: remote camera full-screen (`CallVideoView`, cover fit), a shared
  screen still wins the stage, local preview is `LocalCameraPreview` with the
  flip button on it. CallKit gets `type: 1` and "Video call" as the handle.

## A call answered on a locked phone keeps the phone locked

Added 2026-09-10, after "my phone is locked, the call screen comes, I press
Answer and it asks me to unlock". Two bugs on one path:

```
Accept on CallKit's lock-screen Activity
  -> onAcceptClick: requestDismissKeyguard()   the PIN pad
  -> TransparentActivity -> getAppIntent       no NEW_TASK: a SECOND MainActivity
```

- **The PIN pad was the plugin's own `dismissKeyguard()`.**
  `android/patches/callkit-accept.gradle` removes it at configure time — the
  same pinned-source approach as the manager-lifetime patch in
  `settings.gradle.kts`, and it fails the build loudly after a plugin bump
  rather than quietly putting the PIN pad back.
- **Every Accept on a running app booted a second MainActivity and a second
  FlutterEngine.** `AppUtils.getAppIntent` runs from `TransparentActivity`'s
  own task and `cloneFilter()` drops the launch intent's NEW_TASK, so the app
  was launched into that task instead of its own. Seen on an emulator as two
  tasks each holding `.Launcher`. The same patch file adds NEW_TASK.
- **The call runs over the keyguard, and only the call.** Signal's
  `WebRtcCallActivity.setTurnScreenOnForCallState` holds `setShowWhenLocked`
  for a whole call because that Activity holds nothing else; ours is the one
  FlutterActivity for the entire app. `CallLockScreen.kt` raises the flag on
  the Accept intent (waiting up to 30 s for a cold engine to boot and fetch the
  call) and while Dart reports a live call's own screen on top —
  `callScreenOnTop` in `call_lock_screen_host.dart`: `/call` with a non-idle
  DM call (so "Call ended" stays for its moment), `/group-call` while joining
  or connected. Never the lobby, never a chat.
- **Two covers, because Dart paints before any message reaches native.** A
  black native view over the FlutterView (`CallLockWindow`) from Accept until
  the call's frame is on screen — a cold engine draws its whole boot sequence
  first — and again from the moment the call screen goes until unlock; and
  `CallLockScreenGuard`, which blacks out every non-call route in the very
  frame it would paint. **Both exist only while the app is over the keyguard.**
  Behind it the keyguard already hides the app, and the first version, which
  masked whenever the phone was locked, flashed blank on every unlock.
- **Leaving the call screen on a locked phone drops the app behind the
  keyguard**: cover first, then the flag, so the keyguard animates back in over
  black. Hang-up does the same once "Call ended" has shown.
- **A dead Accept lets go at once.** `AndroidCallUi.endCall` and
  `AndroidGroupCallUi.endCall` call `AndroidCallLockScreen.release(callId)`;
  when that is the call an Accept is waiting for, the lock screen comes back
  now rather than after the 30 s cap.
- **The ongoing-call entry is on the lock screen now.** Signal's `call_status`
  is LOW, which a locked Pixel hides; Signal gets away with it because Back and
  Home enter PiP, which Android gates on the PIN. A DM call here has no PiP — minimising
  pops the screen, and only `GroupCallScreen` arms `AndroidPip` — so a call answered while locked and
  then minimised had no way back and no Hang up short of the PIN. Channel
  `call_ongoing` is DEFAULT importance with no sound and no vibration; the old
  channel is deleted. Its tap lands on `CallReturnActivity`, declared
  `showWhenLocked` — SystemUI asks for the PIN before launching any
  notification Activity that is not, and MainActivity must never be — which
  forwards to MainActivity. `CallLockScreen` honours that return only while
  Dart reports a live call; the entry can outlive one.
- **Speaker on a call answered here goes through Telecom**, not LiveKit — see
  "A call Android Telecom is hosting" under audio routing above.
- Only those two intents lift the app over a lock screen, and even a forged one
  shows nothing but a live call's own screen: Dart masks everything else.
- Verified on an emulator with a PIN: `tool/audit/locked_call_harness.dart` +
  `tool/audit/locked_call_check.py` (answer, minimise, return from the lock
  screen, hang up; `--decline`). Never point it at a real phone.

## One Telecom call per call id

Added 2026-09-12, after "the phone says I am in a call and the SIM dialer
refuses to place one", cleared only by uninstalling the app. Reproduced on an
emulator: presenting one incoming call id twice, close together, left two
Android Telecom connections behind.

```
showCallkitIncoming x2   (UI isolate and the FCM background isolate)
  -> find(callId) == null on BOTH    Telecom creates connections asynchronously
  -> addNewIncomingCall x2           two connections, one map slot
  -> hangup destroys the LAST one    TC@8 DESTROYED, TC@7 still RINGING
                                     audio mode stuck at MODE_RINGTONE
```

The WebRTC call, the microphone, the UI and the notification were all gone. The
orphan was invisible and outlived everything except a force-stop.

- **Reserve before requesting, attach afterwards.**
  `CallkitCallLifecycle.begin(id)` inserts the id under one lock _before_
  `addNewIncomingCall`, so the second presentation loses; `attach()` never
  overwrites an owner — it disconnects the late or duplicate `Connection` it
  was handed instead of dropping the reference to the live one. The plugin's
  `ConcurrentHashMap` was correct per entry and useless across an asynchronous
  create: the whole race lives between the check and the callback.
- **This is Signal's shape.** Only `IdleActionProcessor` accepts a new incoming
  call and every other state ignores one; each system call has its own
  `TelecomCallController`, and a disconnect goes through that controller rather
  than a global `callId -> one Connection` lookup.
- **An Answer or a Hangup that arrives before the connection exists is kept,
  not dropped.** `accept()` sets a flag `attach()` replays; `end()` before the
  callback tombstones the id, so the connection Telecom creates a moment later
  is disconnected the instant it arrives. Both happen for real — a killed app's
  Accept, and a caller cancelling inside the same second.
- **Ended ids are remembered (256, FIFO) and cannot be presented again.** Call
  ids are per-call UUIDs, and Dart already refuses to re-ring an id it has
  answered or withdrawn (`GroupCallInvites._answered`), so this only closes a
  re-entry the app never wants. It lives in one process; a restart forgets it,
  which is right — the connection it was guarding died with the process.
- **`hideIncoming` is not an end.** Handing a ringing call to the Flutter screen
  keeps the owner, so `canPresent` still says yes and the native surface can be
  shown again. Accepted and ended calls cannot.
- **Telecom is released BEFORE media teardown**, in `finishLocal` and in
  `shutdown` (`voice_call_provider.dart`). It used to run after
  `_resetResources`, so a WebRTC dispose that threw or hung was enough to keep
  the phone busy for the SIM dialer.
- **The patch is applied to the pinned plugin source at configure time**,
  `android/patches/callkit-lifecycle.gradle` — same approach as
  `callkit-accept.gradle`, and it throws a `GradleException` on a plugin bump
  rather than quietly not applying. That is why `pubspec.yaml` pins
  `flutter_callkit_incoming: 3.1.3` exactly, with no caret.
  `CallkitConnection`'s companion forwards to the owner, and `unregister` now
  takes the connection so a stale object cannot evict a live one.
- `onCreateOutgoingConnection` carries the same admission guard, but nothing
  reaches it: the plugin never places an outgoing Telecom call, and Dart's
  `startCall` only raises the ongoing notification and its service.
- Verified on an emulator, `android/app/src/androidTest/kotlin/com/ababilx/app/`:
  `CallkitLifecycleTest` (7 tests over real `Connection` objects — 16 threads
  racing `begin`, duplicate attach, hangup-before-callback, answer-before-
  callback, `endAll` over a call that has no connection yet) and
  `CallkitTelecomTest` (5 sessions through the real `ConnectionService`,
  asserting exactly one `[Call id=` in `dumpsys telecom` and `MODE_NORMAL`
  after each end).

  ```
  adb shell am instrument -w com.ababilx.app.test/androidx.test.runner.AndroidJUnitRunner
  ```

  Needs an **idle** emulator: the Telecom test asserts `mCalls:` is empty before
  it starts, and it reads `dumpsys` rather than a mock. Never point it at a
  phone with a SIM.

- Not reproduced on a real device — the emulator's orphan matches the reported
  symptom exactly, but the device case was only ever seen once, by hand.
