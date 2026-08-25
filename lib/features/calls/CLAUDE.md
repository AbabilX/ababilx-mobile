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

- Android plays the **user's system ringtone**; fallback order is system
  ringtone → notification default → bundled `raw/clear_agenda`
  (`RingtoneSource.ringtoneCandidates`). Flip that order there if a branded tone
  is ever wanted.
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

Upgrading `flutter_callkit_incoming` does not remove the need for any of this;
re-read `CallkitSoundPlayerManager` / `CallkitNotificationManager` after a bump
and confirm the two kill switches, then keep `silent_ring`.

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
