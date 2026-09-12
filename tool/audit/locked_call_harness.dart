// Emulator-only fixture for tool/audit/locked_call_check.py — never a release
// entrypoint. Rings a fake CallKit call and plays the app's half of it: the
// call screen, minimising it, and the ongoing-call notification.
import 'dart:async';

import 'package:ababilx/features/calls/audio/telecom_audio_route.dart';
import 'package:ababilx/features/calls/native/android_ongoing_call.dart';
import 'package:ababilx/features/calls/widgets/call_lock_screen_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

String _callId = const Uuid().v4();

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(const MaterialApp(home: Fixture()));
}

class Fixture extends StatefulWidget {
  const Fixture({super.key});

  @override
  State<Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<Fixture> {
  bool live = false;
  bool onScreen = false;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _subs.add(
      FlutterCallkitIncoming.onEvent.listen((event) {
        if (event is CallEventActionCallAccept) _accept();
      }),
    );
    _subs.add(
      AndroidOngoingCall.actions.listen((action) {
        if (action == OngoingCallAction.returnToCall && live) {
          setState(() => onScreen = true);
        }
        if (action == OngoingCallAction.hangUp) unawaited(_end());
      }),
    );
    // A clean slate: an accepted record left by an earlier run would
    // otherwise "connect" at boot and pass every check without one Accept.
    unawaited(FlutterCallkitIncoming.endAllCalls());
    unawaited(AndroidOngoingCall.stop(force: true));
  }

  void _accept() {
    if (live) return;
    // The delay is the point: nothing but the cover may show meanwhile.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        live = true;
        onScreen = true;
      });
      unawaited(
        AndroidOngoingCall.start(callId: _callId, title: 'Return to lock test'),
      );
      unawaited(_probeRoute('accepted'));
    });
  }

  /// Telecom hosts the call once CallKit's Answer ran, and only then. The
  /// check reads these lines back from logcat.
  Future<void> _probeRoute(String when) async {
    for (final speaker in [false, true]) {
      final handled = await TelecomAudioRoute.route(_callId, speaker: speaker);
      debugPrint('[harness] route $when speaker=$speaker handled=$handled');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _end() async {
    await FlutterCallkitIncoming.endAllCalls();
    await AndroidOngoingCall.stop(force: true);
    if (mounted) {
      setState(() {
        live = false;
        onScreen = false;
      });
    }
  }

  Future<void> _ring() async {
    await FlutterCallkitIncoming.endAllCalls();
    _callId = const Uuid().v4();
    await Future<void>.delayed(const Duration(seconds: 5));
    await FlutterCallkitIncoming.showCallkitIncoming(
      CallKitParams(
        id: _callId,
        nameCaller: 'Lock test',
        appName: 'AbabilX',
        handle: 'Voice call',
        type: 0,
        duration: 60000,
        android: const AndroidParams(
          isShowFullLockedScreen: true,
          isFullScreen: false,
          isCustomNotification: true,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    await _probeRoute('ringing');
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingCall = live && onScreen;
    return CallLockScreenGuard(
      callVisible: showingCall,
      callLive: live,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(showingCall ? 'CALL CONNECTED' : 'PRIVATE CHAT CONTENT'),
              ElevatedButton(
                onPressed: _ring,
                child: const Text('RING IN FIVE SECONDS'),
              ),
              ElevatedButton(
                onPressed: () => setState(() => onScreen = false),
                child: const Text('MINIMIZE'),
              ),
              ElevatedButton(onPressed: _end, child: const Text('END CALL')),
            ],
          ),
        ),
      ),
    );
  }
}
