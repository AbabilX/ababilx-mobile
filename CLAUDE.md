# ababilx-mobile — iOS work must not break Android

## Recent reliability fixes — 2026-09-23

- Push/sleep audit: [failure mechanism, recovery changes, tests and device-validation limits](lib/features/notifications/PUSH_RELIABILITY_FIX.md).
- 2026-09-30 round 2 (same file): FCM demotion by silent high-priority
  pushes, ring-first call gate, missed-call notice, socket + Local Share
  suspended in background, `adb logcat -s AbabilXPush`.
- Connections → Blocked people now exposes the existing server unblock API.
  See [mobile chat notes](lib/features/messages/CLAUDE.md#unblock-connections--2026-09-23).
  Unblocking removes your block; reconnecting still requires a new request.
- Play Console "edge-to-edge" warnings (Android 15): `MainActivity` and
  `MediaSendActivity` call `WindowCompat.enableEdgeToEdge(window)` (androidx.core
  1.18.0, pinned), the MediaSend theme lost its deprecated bar-colour attributes,
  and `patches/callkit-incoming-ui.gradle` strips the callkit screen's
  `setStatusBarColor`/`setNavigationBarColor`. Play's report on release 28
  named only the callkit screen as the origin; Flutter's own `FlutterActivity`
  / `PlatformPlugin` still contain those calls (gated below API 35) but were
  not listed. Same report's "bitmap optimisation" item is a false pairing:
  "decoded in" = `MediaSendExport.needsShrinking` (an `inJustDecodeBounds`
  header read of a local file), "downloaded in" = media3's
  `DefaultHttpDataSource` (video streaming) — unrelated code, nothing to fix.
  Decode Play's obfuscated names with the AAB's own
  `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`.

## App update check — 2026-09-25

**Every release: bump `lib/core/app_version.dart` with `version:` in
pubspec.yaml.** `test/core/app_version_test.dart` fails when they differ. The
installed build is a hand-written constant on purpose (no package_info plugin),
and it is what the phone sends to the server.

```
launch (+ resume when the last answer is >6 h old)
  GET /v1/api/app/version?platform=android&build=<appBuildNumber>   public, bare Dio
  update_required  -> AppUpdateRequiredScreen covers the app (not during a call)
  update_available -> bottom sheet once per build per launch; Later = 24 h snooze
  Update           -> market://details?id=… then the https store link
```

- `lib/features/app-update/`, mounted as `AppUpdateGate` inside
  `CallLockScreenHost` in `app.dart`. Its Stack keeps go_router's navigator in
  slot 0 at all times (the ActiveCallBanner GlobalKey crash).
- The forced screen sits ABOVE the navigator: no Overlay there, so nothing on
  it may need one (no SelectableText, no tooltip). Pinned by
  `test/features/app_update/app_update_required_screen_test.dart`.
- A failed or malformed check never blocks: null / "no update".
- Releases, the required flag and the minimum build are set in the web admin
  Control Zone → App updates (`Ababil-X-frontend`). Publish only once Play
  serves the build to everyone; a required release during a staged rollout
  blocks phones Play has not reached. The server never forces past the newest
  published build.

**Android is the shipped, device-verified baseline.** Calls, CallKit/Telecom,
ringtone, media send, share intake, notifications and the lock-screen call all
work on real phones and took many rounds to settle. iOS is being brought up
beside it. Every iOS change is judged first by one question: **does Android
build and behave exactly as before?** If the answer is not a clear yes, stop
and ask.

## Home bottom bar (BNB)

Visible tabs = **team/CRM access ∩ device-local prefs**.

- Server gate: `hasTeamProvider` / `canViewCrmProvider` (`/api/teams/me`).
- Device prefs: `shellNavPrefsProvider` (SharedPreferences keys
  `ababilx_shell_nav_wall|crm|board`) — Settings → Navigation, shown only
  when `hasTeam`. Turning a switch off hides the tab from the bar only;
  deep links still open the route. Leaving a team still redirects
  `/wall` `/board` `/crm` to Messages via `shellRouteAccessDenied`.
- **Chats ↔ Talks swipe** (2026-09-30, `core/router/swipe_tab_pager.dart` +
  `home_tab_pager.dart`): `/messages` and `/calls` build ONE `MaterialPage`
  keyed `home-tab-pager`, so a route change updates the page and the
  `PageView` inside just moves. Do not give them separate keys again — the
  pager would be rebuilt on every tab change. The route stays the truth; a
  swipe calls `context.go` only when the page settles. **Both pages are built
  up front and kept alive** — building one as the finger moved (Chats also
  re-decrypted previews + refetched) is what made the first version stutter.
  So initState/dispose no longer mean opened/closed: per-visit work uses
  `SwipeTabActive` / `SwipeTabVisits` (`swipe_tab_active.dart`) — Talks marks
  missed calls seen on hide, reloads on show, closes its search on hide (its
  PopScope would swallow Back on Chats), and only the visible tab may raise
  the vault unlock sheet. Wall / CRM / Board are not in the pager.

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
