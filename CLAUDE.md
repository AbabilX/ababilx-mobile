# ababilx-mobile — iOS work must not break Android

**Android is the shipped, device-verified baseline.** Calls, CallKit/Telecom,
ringtone, media send, share intake, notifications and the lock-screen call all
work on real phones and took many rounds to settle. iOS is being brought up
beside it. Every iOS change is judged first by one question: **does Android
build and behave exactly as before?** If the answer is not a clear yes, stop
and ask.

## Zones

```
FREE for iOS work          ios/**  (Swift, Podfile, xcconfig, Info.plist,
                           entitlements, Runner.xcodeproj), new iOS-only
                           Dart files, code inside a Platform.isIOS branch

ASK FIRST                  shared Dart on a path Android executes,
                           pubspec.yaml / pubspec.lock, packages/** Dart

NEVER without explicit     android/**  (Kotlin, Gradle, AndroidManifest,
user approval              res/, android/patches/*.gradle, proguard),
                           packages/*/android/**
```

## Rules

1. **Gate, don't generalise.** New behaviour for iOS goes behind
   `Platform.isIOS` (or `defaultTargetPlatform == TargetPlatform.iOS` where
   `dart:io` is unavailable), or in an iOS-only file. Never restructure the
   Android path "for symmetry" or "to share code" while doing iOS work.
2. **Method channels are a frozen contract.** The Kotlin side defines the
   channel name, method names, argument keys and return shape. The Swift
   implementation matches that contract exactly — it never renames, reorders
   or reinterprets. A method only iOS needs is added so that Android's
   existing `notImplemented` / `MissingPluginException` path is harmless, and
   the Dart caller is gated to iOS.
3. **A plugin change is an Android change.** `pubspec.yaml` is shared, so a
   bump or a new plugin also changes Android's Gradle dependencies. Before
   touching a dependency: read the plugin's CHANGELOG `[Android]` entries,
   diff the plugin's `android/build.gradle` old vs new, tell the user what
   moves on Android, and get a yes. Exact pins (`flutter_callkit_incoming:
   3.1.3`) are **never** bumped — the patches under `android/patches/` are
   text-matched against that source.
4. **No shared-Dart edit "while we are here".** An iOS task does not fix,
   tidy or rename Android-path code. Spot a problem there → report it, don't
   change it.
5. **Signal-iOS is the reference, read-only.** `../examples/Signal-iOS` is
   AGPL-3.0, like Signal-Android: read it for the approach and the platform
   API it uses, then write our own Swift. Never paste from it.
6. **Native-first on iOS too.** Where Android does the work in Kotlin behind a
   thin Dart layer, iOS does it in Swift behind the **same** Dart layer — so
   Dart stays one code path and each platform owns its native half.

## Done means, for any iOS change

- `git diff --stat -- android packages/*/android` is **empty** (or the user
  approved each line of it).
- Every shared-Dart hunk in `git diff -- lib` is inside an iOS gate, or is
  explained to the user as Android-neutral.
- `flutter analyze` passes and `flutter build apk --debug` still builds.
- If a dependency moved: name the Android screen to re-test on a device
  (e.g. "scan a QR on Android"), because a green build does not prove the
  camera still opens.
