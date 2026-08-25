# Incoming-call ringtone (Android) — DO NOT REWORK

> Shipped 2026-08-25 after a "ringtone dies ~2 s in" bug. Verified working on
> device. Every line below exists because something broke without it. Read this
> before editing anything under `ringtone/`, `native/`, or
> `packages/call_ringer/`.

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
`group/providers/group_call_callkit.dart`,
`android/app/src/main/kotlin/com/ababilx/app/MainActivity.kt` (releases the
`flutter` holder in `onDestroy`), `res/raw/keep.xml`, `gradle.properties`.

Upgrading `flutter_callkit_incoming` does not remove the need for any of this;
re-read `CallkitSoundPlayerManager` / `CallkitNotificationManager` after a bump
and confirm the two kill switches, then keep `silent_ring`.

## Device test (emulators do not prove this)

Background the app, call, let it ring 30 s+. Repeat locked, repeat with the app
killed, repeat while changing volume and with an OEM increasing-ring ramp on.

```bash
adb logcat -s CallRinger:V CallRingerPlugin:V flutter:V
```
