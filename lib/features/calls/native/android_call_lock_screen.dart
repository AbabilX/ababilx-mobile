import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What native knows about the keyguard, as far as a call is concerned.
@immutable
class CallLockState {
  const CallLockState({required this.locked, required this.overLock});

  static const unlocked = CallLockState(locked: false, overLock: false);

  /// The keyguard is up.
  final bool locked;

  /// The app is allowed over it right now: a call is on screen, or an Accept
  /// is on its way to one.
  final bool overLock;

  /// Anything the app paints now is seen on a locked phone.
  bool get exposed => locked && overLock;

  CallLockState copyWith({bool? overLock}) =>
      CallLockState(locked: locked, overLock: overLock ?? this.overLock);

  static CallLockState parse(Object? raw) => raw is Map
      ? CallLockState(
          locked: raw['locked'] == true,
          overLock: raw['overLock'] == true,
        )
      : unlocked;
}

/// A call answered on a locked phone runs over the keyguard, and nothing else
/// does — `CallLockScreen.kt` holds the flag, `CallLockScreenGuard` the mask.
///
/// No-op off Android, and in the FCM background isolate, which has no
/// Activity and therefore no channel.
class AndroidCallLockScreen {
  AndroidCallLockScreen._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/call_lock_screen',
  );

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<CallLockState> read() async =>
      CallLockState.parse(await _invoke('state'));

  /// [visible]: a live call's own screen is the top route. [live]: a call is
  /// ringing, connecting or up — what a lock-screen tap on the ongoing-call
  /// notification needs before it may open anything.
  static Future<void> setCallState({
    required bool visible,
    required bool live,
  }) async {
    await _invoke('setCallState', {'visible': visible, 'live': live});
  }

  /// A native call was ended. If an Accept on a locked phone was waiting for
  /// it, no call screen is coming, and the lock screen returns now instead of
  /// after native's timeout.
  static Future<void> release(String callId) async {
    if (callId.isEmpty) return;
    await _invoke('release', {'callId': callId});
  }

  /// Native pushes every change here. One listener: the guard.
  static void listen(void Function(CallLockState state)? onChanged) {
    if (!supported) return;
    _channel.setMethodCallHandler(
      onChanged == null
          ? null
          : (call) async {
              if (call.method == 'changed') {
                onChanged(CallLockState.parse(call.arguments));
              }
            },
    );
  }

  static Future<Object?> _invoke(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
