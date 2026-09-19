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
  }) {
    final call = VoiceCallState(
      phase: phase,
      pendingPeerName: 'Rahim Uddin',
      connectedAt: DateTime(2026),
    );
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
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
    'large Bengali labels and landscape keep End reachable without overflow',
    (tester) async {
      const size = Size(568, 320);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var ended = false;
      await tester.pumpWidget(
        host(
          ThemeData(),
          lang: 'bn',
          scale: 2,
          size: size,
          end: () => ended = true,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byIcon(Icons.call_end_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      expect(ended, isTrue);
      expect(find.text('শেষ করুন'), findsOneWidget);
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
