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
  (keeps resource *names*, which `keep.xml` alone does not).

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
UI. Nothing then replaced it for the *connected* phase, and `/call` is an
ordinary route with no `PopScope` — so back popped it and left a live WebRTC
session with no way in and no way out. The call ran until the peer hung up or
the server sweeper expired it.

Two surfaces now cover that, both Signal's:

- `OngoingCallService` + `OngoingCallNotification` (Kotlin) — an ongoing
  `CallStyle.forOngoingCall` entry on its own low-importance `call_status`
  channel. Tap the body to return, press Hang up to end it from the shade.
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
  *someone* started the call, not when this device joined, and a wrong timer is
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
That kills the notification *and* the plugin's foreground service — CallKit
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
accept is merely *in flight* too — the point of the return value is "do not put
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

## The call screens are Signal's layout

`IncomingCallView` and `ConnectedCallBody` are built from
`IncomingCallScreen.kt` / `CallScreen.kt`: the caller's own photo blurred
across the window under a black scrim (0.4 while ringing, 0.35 once up), a
call-type line, the avatar, the name, the status, and the actions at the
bottom edge. Every string carries `callTextShadow`, because all of it sits on
a photograph. The buttons are `CallControlButton`, whose colours are hardcoded
rather than taken from `ColorScheme` — a call screen is always dark, and a
light-theme surface colour would disappear into the blur. This is the one place
in the app where the "use Theme.colorScheme" rule is deliberately not followed.

The label is **Answer**, not "Accept" — Signal's word, and every dialler's.

The native full-screen surface over the lock screen is still
flutter_callkit_incoming's Activity and its layout is not ours to change. What
we can set, we do: `backgroundUrl` is the caller's avatar, with a dark
`backgroundColor` behind it and a green `actionColor` (see
`AndroidCallUi._params`). Do not replace that Activity to chase pixel parity
without re-reading the ringtone sections above first — the ring holder handoff
is built on it.

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
registered one — the projection type must be in place *before* capture begins.

Do not add a second foreground service for capture. If a new capture surface
needs a type, add it to that mask.

## A dropped media path is restarted, not hung up

Added 2026-09-04, for "long calls die when I walk around".

`VoicePeerEngine` used to end the call 12 s after `RTCPeerConnectionState
Disconnected`, and immediately on `Failed`. Neither state recovers on its own —
the candidate pair carrying media is gone — so every WiFi-to-mobile handover,
lift, tunnel and carrier IP reassignment killed a live call. The longer the
call, the likelier one of them fires.

The engine now only *reports* those transitions (`onTrouble`), and
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
  Going *offline* is deliberately not actionable: there is nothing to restart
  onto. Coming back resets the recovery budget, or an outage longer than
  `giveUpAfter` would kill the call exactly when it became recoverable.
- **A hard deadline runs beside the attempt chain.** An attempt that hangs (a
  socket connect that never returns on a dead network) would otherwise leave
  "Reconnecting…" on screen with nothing left to end it.
- **Attempts never overlap, and carry a generation.** `_schedule` cancels the
  pending *timer*, not an attempt already awaiting a TURN fetch — so a
  connectivity event mid-fetch used to start a second attempt whose older
  credentials could land *after* the newer ones. `_attemptInFlight` queues
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

Group calls need none of this: a LiveKit `Room` configures the session itself.
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
- **`Icons`-free is a rule for the call surface only.** Colours are hardcoded
  in `CallSurface` for the same reason `CallControlButton`'s are: a call screen
  is always dark.
