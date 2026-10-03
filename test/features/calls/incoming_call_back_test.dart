import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/calls/audio/call_audio_devices.dart';
import 'package:ababilx/features/calls/audio/call_audio_output.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:ababilx/features/calls/screens/incoming_call_view.dart';
import 'package:ababilx/features/calls/screens/voice_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/call_fakes.dart';

/// Back used to pop the ringing screen — and the tone with it — while the
/// call went on ringing with nothing left to answer or decline it.
class _Ringing extends VoiceCallNotifier {
  @override
  VoiceCallState build() => VoiceCallState(
    phase: VoiceCallPhase.incomingRinging,
    currentUserId: 'me',
    call: testCall('B'),
  );
}

void main() {
  testWidgets('system back does not dismiss a ringing call', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in [
      'com.ababilx.app/call_ringer',
      'com.ababilx.app/call_screen_lock',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/events/ababilx_call_ringtone',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceCallProvider.overrideWith(_Ringing.new),
          appLanguageProvider.overrideWithValue('en'),
          callAudioDevicesProvider.overrideWith(
            (ref) => Stream.value(CallAudioDevices.empty),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          // The ringing view sizes itself from MediaQuery; keep it in step
          // with the surface, as `incoming_call_view_test` does.
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: child!,
          ),
          home: const Scaffold(body: Text('chat')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const VoiceCallScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IncomingCallView), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Back was taken — the app does not exit — and the ring is still there.
    expect(handled, isTrue);
    expect(find.byType(IncomingCallView), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);

    // Take the screen down so its timers go with it.
    navigator.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
