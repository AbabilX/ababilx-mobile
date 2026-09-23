# Push registration recovery — 2026-09-23

## Observed problem and evidence

Some phones appeared to stop receiving AbabilX notifications while WhatsApp
continued working. The affected phone's delivery trace was not captured, so
this audit does not prove a single cause for every incident.

The code did contain a recovery gap: FCM token lookup/API registration errors
were swallowed while startup became complete. A temporary Firebase or network
failure could therefore leave the server without a usable token, without a
retry when connectivity returned. Separately, the battery warning needed 50
received samples over three days. A phone receiving nothing could never meet
that threshold.

## Changes and why they help

- `data/push_token_registration.dart` retries failed token acquisition, local
  token storage and server registration after 5/10/20/40/80/160 seconds, capped
  at 300 seconds. `fcm_bootstrap.dart` also retries pending work on app resume
  and network recovery. A transient failure is no longer terminal for the
  running session; a healthy registration does not repeat on every resume.
- `fcm_service.dart` keeps notification listeners independent of a slow token
  POST. A single in-flight registration and revision checks handle token
  rotation. Logout disables retries and waits for any registration POST before
  deregistering, preventing a late POST from restoring a logged-out token.
  Session guards also prevent stale startup from reattaching after logout.
- Android's explicit background-restricted flag can trigger the battery
  guidance without latency samples. Permission, dismissal and backoff gates
  remain. Doze exemption alone is no longer presented as proof that all OEM
  restrictions have been removed; settings stay accessible.
- `main.dart` records background push receipt, chat handling and failure type
  without message contents, helping distinguish arrival from handling failure.

The existing high-priority FCM delivery, Android encrypted data-only payload,
placeholder-before-decryption display, encryption and call routing are
unchanged. No permanent background service or keep-awake loop was added.
Timers recover registration while execution is available; they cannot run
through an OS suspension or override a force-stop/manufacturer restriction.

## Verification and limits

232 tests passed across notifications, authentication, calls and WebSocket
reconnect; targeted Flutter analysis reported no issues. Regression tests cover
missing tokens, lookup/storage/API failures, recovery, rotation, denied
permission, concurrent startup and logout races.

At completion of this code change, no new APK was installed or deployed and
no affected-phone locked-screen/idle delivery test had been performed. These
changes fix demonstrated code gaps, not a verified universal OEM sleep cure.
Release verification still needs an affected phone: install the new build,
verify registration after offline startup/network recovery, then deliver chat
and call pushes while backgrounded and after extended screen-off idle. Check
per-app battery/auto-start restrictions if server delivery succeeds but the
background receipt log never appears. Compare timestamps and permissions;
WhatsApp working alone does not identify where AbabilX delivery stopped.

Official platform references: [Android Doze](https://developer.android.com/training/monitoring-device-state/doze-standby),
[Samsung app management](https://developer.samsung.com/mobile/app-management.html).
