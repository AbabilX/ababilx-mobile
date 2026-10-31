# AbabilX Mobile

[![Flutter](https://img.shields.io/badge/Dart%20SDK-%5E3.12.0-blue.svg)](https://flutter.dev/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen.svg)]()

The AbabilX chat app for Android, written in Flutter with native Kotlin for
calls, media and backup. Messages are end-to-end encrypted, and the server keeps
a message only until your phones have it.

iOS is not a release target yet. Some features are Android only.

---

## Features

**Messaging**
- Direct messages, groups and Note to Self, end-to-end encrypted
- Encrypted file attachments, voice notes, snippets and link previews
- Replies, threads, reactions, forwarding, pins and multi-select
- Delivery ticks, with a green double tick once a message is seen
- Task cards in a DM, and Send later for scheduled messages

**Calls**
- 1:1 voice and video over peer-to-peer WebRTC
- Group calls over LiveKit, with screen sharing, raised hands and reactions

**Privacy**
- Privacy mode, per person or for the whole account
- Private chat, Ghost Chat, chat lock and view-once photos
- Group privacy and per-member group permissions
- Safety numbers to check a contact's key

**Your data**
- Automatic local backup, and restore from a backup file
- Transfer chats to a new phone or computer on the same Wi-Fi
- Local Share for files and text between devices on the same Wi-Fi
- Link a computer or browser by scanning one QR code

---

## Tech stack

| Area | Used |
| --- | --- |
| App | Flutter, Dart |
| State and navigation | Riverpod, GoRouter |
| Network | Dio, WebSocket |
| Calls | flutter_webrtc, LiveKit |
| Local storage | Drift, SQLCipher, Flutter Secure Storage |
| Push | Firebase Cloud Messaging |
| Native code | Kotlin under `android/app/src/main/kotlin/` |

---

## Setup

You need the Flutter SDK (Dart `^3.12.0`) and Android Studio.

```bash
git clone https://github.com/AbabilX/ababilx-mobile.git
cd ababilx-mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Firebase and signing files are not in this repository. To build, add your own
`android/app/google-services.json`, or run `flutterfire configure`.

```bash
flutter run
```

The app uses `https://api.ababilx.com` by default. To use your own server:

```bash
flutter run --dart-define=ABABILX_API_URL=http://<your-ip>:7896
```

Run the tests:

```bash
flutter test
```

---

## Thanks

This app learned a lot from these open-source projects. Thank you to the people
who build them. AbabilX is not affiliated with or endorsed by either project.

### Signal

[Signal-Android](https://github.com/signalapp/Signal-Android), licensed under
[AGPL-3.0](https://github.com/signalapp/Signal-Android/blob/main/LICENSE),
Copyright Signal Messenger, LLC. No Signal assets are included.

These parts were written from Signal's source, with its logic translated:

| Here | Signal source |
| --- | --- |
| `android/.../callaudio/` (call audio routing) | `SignalAudioManager`, `FullSignalAudioManager`, `FullSignalAudioManagerApi31`, `SignalBluetoothManager` |
| `lib/shared/link-preview/link_safety.dart` | `LinkUtil` |
| `lib/shared/link-preview/` (fetching, limits) | `LinkPreviewRepository`, `LinkPreviewUtil` |
| `lib/features/messages/safety_number/safety_number.dart` | Numeric fingerprint algorithm |
| `lib/features/messages/chat-timeline/signal_*.dart` (message menu) | `ConversationReactionOverlay` |

Many other screens and behaviours follow Signal's design, including the media
picker, calls, chat bubbles and multi-select. The code comments name the Signal
class where one was followed.

### LocalSend

[LocalSend](https://github.com/localsend/localsend), licensed under
[Apache-2.0](https://github.com/localsend/localsend/blob/main/LICENSE). Local
Share follows its approach of finding devices by UDP multicast and sending files
over plain HTTP, and uses the same multicast address, `224.0.0.167`. It has its
own protocol and does not work with LocalSend apps. No LocalSend code is included.

---

## License

Copyright (C) 2026 AbabilX contributors.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, version 3. It comes with no warranty. See [LICENSE](LICENSE).

Parts of this app are based on Signal, as listed under [Thanks](#thanks).
Third-party packages and fonts keep their own licenses.
