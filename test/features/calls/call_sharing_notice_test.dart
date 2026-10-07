import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:ababilx/features/calls/widgets/connected_call_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(390, 844), Size(844, 390)]) {
    testWidgets('own screen share line sits at the top of $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const inset = EdgeInsets.only(top: 32);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, padding: inset),
            child: Scaffold(
              body: ConnectedCallBody(
                call: VoiceCallState(
                  phase: VoiceCallPhase.connected,
                  pendingPeerName: 'Rahim Uddin',
                  connectedAt: DateTime(2026),
                  screenSharing: true,
                ),
                onMinimize: () {},
                onSwitchCamera: () {},
                controls: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      final line = tester.getRect(find.text('You are sharing your screen'));
      // Under the status bar, over the caller's name.
      expect(line.top, greaterThan(inset.top));
      expect(line.bottom, lessThan(size.height * 0.2));
      expect(
        line.bottom,
        lessThan(tester.getRect(find.text('Rahim Uddin')).top),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
