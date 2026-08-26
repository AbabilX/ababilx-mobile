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
`android/app/src/main/kotlin/com/ababilx/app/MainActivity.kt` (releases the
`flutter` holder in `onDestroy`), `res/raw/keep.xml`, `gradle.properties`.

The connected-call surface is its own cluster: `ongoing_call_sync.dart`,
`native/android_ongoing_call.dart`, `native/android_screen_share.dart`,
`widgets/active_call_banner.dart`, `app.dart` (mounts both), and
`android/app/src/main/kotlin/com/ababilx/app/OngoingCall{Service,Notification,Channel}.kt`
plus the `.OngoingCallService` manifest entry.

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
- `ActiveCallBanner` — the in-app bar for the commoner case, where the user
  pressed back but is still inside AbabilX.

`OngoingCallSync` owns both: it mirrors `voiceCallProvider` / `groupCallProvider`
onto the notification and routes the two presses back. The DM call wins when
both somehow exist — it is the one whose audio is live.

`OngoingCallChannel` is **Activity-scoped**, unlike `call_ringer`, and that is
correct rather than an oversight: a connected call lives in the Flutter
isolate, so an engine that is gone means a call that is already over. A
ringtone has the opposite requirement — see the plugin-package section above.

## Back on a live call shrinks it — it does not close it

Added 2026-08-26, alongside the surfaces above.

Signal's `WebRtcCallActivity` calls `enterPipModeIfPossible()` from its back
handler and from `onUserLeaveHint`, so leaving a call screen produces a
floating window rather than a call with nowhere to go. `PipController` does the
same, with one difference that matters: Signal's call has its own Activity and
ours does not, so PiP must be **armed and disarmed**. `AndroidPip.setActive` is
called by `VoiceCallScreen` and `GroupCallScreen` while a shrinkable call is on
screen, and native `enter()` refuses when it is off — otherwise Home on the
chat list would shrink the whole app into a thumbnail.

- Armed for connected / connecting / outgoing-ringing. **Never for an incoming
  call**: a thumbnail has nowhere to put Answer, and Signal does not shrink one
  either.
- API 31+ gets `setAutoEnterEnabled(true)` so the system animates the Home
  transition itself; older versions fall back to `onUserLeaveHint`.
- `AndroidPip.inPip` drives a compact layout (`PipCallView`) — name, status,
  and nothing else. No controls: the window is too small to hit them, and
  tapping it restores the screen where they live.
- Explicit "minimize" buttons route through `_leave()`, not `popOrGoHome`.
  `Navigator.pop` does not consult `PopScope`, so a button wired straight to
  the old helper would close a call the back gesture would have shrunk.
- Manifest: `MainActivity` carries `supportsPictureInPicture` and
  `resizeableActivity`. Its `configChanges` already lists the size/orientation
  keys PiP needs, so the Activity is resized rather than recreated.

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
  `STREAM_VOICE_CALL`, `forceAudioRouting: true`) and the starting route.
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
