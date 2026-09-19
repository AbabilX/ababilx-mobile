import 'dart:io';
import 'dart:ui' as ui;
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:ababilx/features/calls/widgets/call_controls_row.dart';
import 'package:ababilx/features/calls/widgets/connected_call_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(
    ThemeData theme, {
    VoidCallback? end,
    VoiceCallPhase phase = VoiceCallPhase.connected,
    String lang = 'en',
    double scale = 1,
    Size size = const Size(390, 844),
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    final call = VoiceCallState(
      phase: phase,
      pendingPeerName: 'Rahim Uddin',
      connectedAt: DateTime(2026),
    );
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
          viewPadding: viewPadding,
          padding: viewPadding,
        ),
        child: RepaintBoundary(
          key: const ValueKey('caller-screen'),
          child: Scaffold(
            body: ConnectedCallBody(
              call: call,
              lang: lang,
              onMinimize: () {},
              onSwitchCamera: () {},
              controls: CallControlsRow(
                call: call,
                lang: lang,
                onToggleMute: () {},
                onToggleCamera: () {},
                onToggleScreenShare: () {},
                onToggleSpeaker: () {},
                onHangUp: end ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'caller controls are one row + centered End in ${brightness.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        );
        var ended = 0;
        await tester.pumpWidget(host(theme, end: () => ended++));
        await tester.pump();
        final mute = tester.getCenter(find.byIcon(Icons.mic_rounded));
        final camera = tester.getCenter(
          find.byIcon(Icons.videocam_off_rounded),
        );
        final share = tester.getCenter(find.byIcon(Icons.screen_share_rounded));
        final speaker = tester.getCenter(find.byIcon(Icons.hearing_rounded));
        final end = tester.getCenter(find.byIcon(Icons.call_end_rounded));
        expect(mute.dy, closeTo(camera.dy, 0.5));
        expect(camera.dy, closeTo(share.dy, 0.5));
        expect(share.dy, closeTo(speaker.dy, 0.5));
        expect(end.dy, greaterThan(share.dy));
        expect(end.dx, closeTo((mute.dx + speaker.dx) / 2, 1.0));
        expect(
          tester.widget<Icon>(find.byIcon(Icons.call_end_rounded)).color,
          Colors.white,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.mic_rounded)).color,
          Colors.white,
        );
        expect(find.text('End'), findsOneWidget);
        expect(find.text('Screen Share'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.call_end_rounded));
        expect(ended, 1);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CALL_UI_SCREENSHOTS')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('caller-screen')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/tmp/ababilx-caller-${brightness.name}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
  testWidgets(
    'landscape keeps seats on the side strip; End inline; no labels',
    (tester) async {
      const size = Size(568, 320);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var ended = false;
      // Notch on the left (camera after rotate-left) → strip must pin right
      // (portrait bottom / home edge), not the bump.
      await tester.pumpWidget(
        host(
          ThemeData(),
          lang: 'bn',
          scale: 1,
          size: size,
          end: () => ended = true,
          viewPadding: const EdgeInsets.only(left: 48),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('শেষ করুন'), findsNothing);
      expect(find.text('মিউট'), findsNothing);

      final mute = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final end = tester.getCenter(find.byIcon(Icons.call_end_rounded));
      expect(end.dx, closeTo(mute.dx, 2.0));
      expect(end.dy, isNot(closeTo(mute.dy, 8.0)));
      expect(mute.dx, greaterThan(size.width * 0.5));

      await tester.tap(find.byIcon(Icons.call_end_rounded));
      expect(ended, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape with notch on the right pins the strip to the left (home)',
    (tester) async {
      const size = Size(568, 320);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          ThemeData(),
          size: size,
          viewPadding: const EdgeInsets.only(right: 48),
        ),
      );
      await tester.pump();
      final mute = tester.getCenter(find.byIcon(Icons.mic_rounded));
      expect(mute.dx, lessThan(size.width * 0.5));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('starting call can be ended before media is ready', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var ended = false;
    await tester.pumpWidget(
      host(
        ThemeData(),
        phase: VoiceCallPhase.starting,
        end: () => ended = true,
      ),
    );
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    expect(ended, isTrue);
  });

  testWidgets('minimize chevron is present on the connected overlay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(ThemeData()));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });
}
