import 'package:flutter/widgets.dart';

/// True while Flutter can still draw the ringing UI, so the in-app call screen
/// and its tone own the ring and CallKit stays down.
///
/// `inactive` counts as on-screen: Android reports it for the notification
/// shade, a system dialog, a screen turning on and ordinary route transitions,
/// all while the call screen is visible. Treating that as "backgrounded" is
/// what silenced the tone a few seconds into a ring and put a native screen
/// over the Flutter one. A genuinely backgrounded app reports `paused` (then
/// `hidden`/`detached`), which is where CallKit takes over.
///
/// Single source of truth for every ring-surface decision — CallStoreSync,
/// both call providers and the FCM push handler must not each pick their own,
/// or one raises CallKit while another tears it down.
bool get flutterOwnsRingingUi {
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  return lifecycle == AppLifecycleState.resumed ||
      lifecycle == AppLifecycleState.inactive;
}
