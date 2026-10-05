# Local Share (mobile)

LAN-only threads with nearby AbabilX devices. Protocol and limits:
`LOCAL_SHARE_PROTOCOL.md` at the monorepo root. Overview: root `CLAUDE.md`,
"Local Share v2".

```
engine/            pure dart:io, no Flutter — tested on loopback
  protocol/        peer, envelope, file rules, ids (fixtures shared with Rust)
  server/          guard -> pair | messages | files (resumable PUT)
  client/          pair, send (3 small files at once, large alone), upload
  discovery/       multicast per LAN interface, presence, /24 sweep fallback
  share_sender     stores the bubble, retries 4x (resume makes it cheap)
  store/           ShareStore interface + MemoryShareStore (tests)
data/              drift DB (own file per account) + ShareStore impl + queries
local_share_engine.dart   facade: db, server, presence, sender for one account
local_share_actions.dart  sendText / sendFiles / delete / forget / block
providers/         engine (null until a device name exists), peers, threads
screens/ sheets/ bubbles/ widgets/   UI — bottom sheets only, Hugeicons only
```

Rules that will bite:

- **Nothing runs until `localShareNameProvider` has a name.** No announce, no
  server. `LocalShareSync` pauses discovery off screen and releases the
  MulticastLock; the server stays bound so a running transfer continues.
- **The engine never answers a pair request itself.** `localSharePairPromptProvider`
  null (no screen) = refused.
- **UI reads the database, not engine state.** Queries are watches over
  `tableUpdates`; the engine writes rows. Progress alone comes from
  `ShareProgressHub` (throttled) via `localShareProgressProvider`.
- **`owned` on a file row** = the app may delete it with the bubble (picker
  cache copy, voice note, anything received). A referenced original is never
  deleted. Owned picks are MOVED into the thread folder by `_adopt`.
- **An incoming file is at `<localPath>.part` until complete** — draw from
  `localPath` only when `file.done || message.fromMe`.
- **Kotlin** (`android/.../localshare/`): `LocalShareNetChannel` (locks +
  starts/stops the service), `LocalShareTransferService` (dataSync FGS, driven
  by `ShareTransferWatch`: progress events = alive, 4 quiet seconds = stop),
  `LocalShareFolderChannel` + `LocalShareFolderWalk` (SAF tree -> cache copies
  with `relPath`; the folder option is hidden where the channel is missing).
- Forward to a chat goes through `shareIntakeProvider.notifier.offer` with
  `file://` URIs — the ordinary share screen takes over and only then uploads.
- Every file ≤ 200 lines. Run `dart run build_runner build` after touching
  `data/local_share_tables.dart`.

Tests: `test/features/local_share/` — fixtures, loopback transfer (pair, auth,
Origin refusal, resume, overflow, delete, progress throttle), and the skipped
Dart↔Rust cross test.
