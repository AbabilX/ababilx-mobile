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

---

# Round 2 — phones "going to sleep" — 2026-09-30

Report: most phones stop receiving chat and call notifications once they have
been idle a while; everything works while the app is open. Registration
(round 1) was not the cause. Three code causes feed each other:

```
silent high-priority pushes  ->  FCM demotes the install to normal priority
fail-closed call gate        ->  rings nothing when its API check fails,
                                 i.e. another silent high-priority push
background drain             ->  Samsung "sleeping apps" / OEM managers cut
                                 the app off (restricted bucket)
normal priority in Doze      ->  call push expires on the way, DMs hours late
```

**1. FCM demotion.** Since Android 13 the standby bucket no longer limits
high-priority FCM; instead FCM lowers an install's high-priority messages to
normal when they arrive without a visible notification (7 days of history, per
install — firebase.google.com/docs/cloud-messaging/android/message-priority).
We sent many: `voice_call_ended` to caller AND callee on every call,
`voice_call_answered`, `group_call_joined`, `group_call_ended` to every group
member after every call, `ghost_closed`. Fix (server `services/notify/fcm_policy.go`,
twin `ababilx-notification/internal/fcm/priority.go`): those go **normal**. A
phone that needs them quickly is ringing, screen on, out of Doze, so normal
still arrives at once. The callee's ended push for an unanswered call carries
`missed_call=1` + caller name, stays high, lives 6 h, and the phone shows
CallKit's "Missed voice call" for it (`calls/native/missed_call_notice.dart`) —
WhatsApp's behaviour, and visible, so it teaches FCM nothing bad.
`group_call_ended` now reaches only phones that can hold a native surface:
members while the ring window is open, joined members after. Every send
carries an FCM `analytics_label` = push type.

**2. Call gate was fail-closed on the network.** `BackgroundVoiceCallGate`
made a sleeping phone fetch the call (expired JWT → 401 → refresh → retry, in
6 s, from a cold isolate) before ringing, and rang nothing on any failure. Now:
local checks only (id, expiry, ended mark, answered-here mark) → ring → then
`dismissIfOver` asks the server and takes the ring down only on a terminal
status. Never on `accepted` (could be this device's own answer before its mark
is written). Offline leaves it ringing; the ended push, the server sweep and
CallKit's timeout still end it.

**3. Background drain.** Local Share ran its 4 s multicast announce, 10 s peer
probe and a 253-host HTTP subnet sweep (over cellular too) for the whole life
of the process; the realtime socket stayed open forever with a 30 s client
ping, a 54 s server ping and every contact's presence/typing events. Now:
Local Share discovery pauses when the app leaves the screen (receive server
stays), the sweep runs only on LAN interfaces (`isLanInterface`, RFC 1918), and
the socket is suspended 2 min after backgrounding (Signal's
`maxBackgroundTime`) unless a 1:1 call, group call or Ghost Chat holds it
(`features/realtime/`). Resume reconnects and resyncs.

The socket was also what sent the **delivered tick** (`chat_provider_ws.dart`),
so suspending it left a pocketed phone's messages on one tick until the app
opened. The FCM background handler now sends it from the push itself
(`chat_push_delivered.dart`, WhatsApp's moment): after the tray entry, with
the push's `message_id` and the already-registered messaging device, never
registering one, never "read". Best effort; the server ignores repeats and
unknown devices. Not covered, because no Dart runs for them: muted chats (the
server sends no push), pushes carrying a notification block (feeds, a
converted group never keyed) and iOS — those still tick on open.

**Also fixed:** `ApiClient` wiped the session when a token refresh failed for
*any* reason — a timeout on a phone just out of Doze signed the user out. Now
only a 401/403 from the refresh endpoint does (`RefreshOutcome`).

## Seeing it on a device

```bash
adb logcat -s AbabilXPush
```

`PushPriorityReceiver.kt` logs `original=` vs `delivered=` priority per push;
`LOWERED` means FCM demoted it. Fleet-wide: FCM Data API
`projects/ababilx/androidApps/<app id>/deliveryData` →
`messageInsightPercents.priorityLowered`,
`deliveryPerformancePercents.delayedDeviceDoze`,
`messageOutcomePercents.droppedAppForceStopped` / `droppedTtlExpired`, now per
`analytics_label`. Demotion is judged over 7 days, so expect the numbers to
recover about a week after the server deploy, not at once.

## Deploy

Server + `ababilx-notification` first (both senders carry the policy), then
the app. Any order is safe: old phones ignore `missed_call`; new phones against
an old server simply show no missed-call notice.

## Not done

- Ringing still needs the Flutter engine to boot in the FCM background
  isolate. Signal/WhatsApp ring from a native `FirebaseMessagingService`; that
  is the next step for killed-app ring latency on low-end phones.
- A user who force-stops the app (or an OEM "cleaner" that does) gets no FCM
  at all until they open it — no code can change that.
- Attendance "online" mode counts socket time; a backgrounded phone now stops
  counting after 2 min.
