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
    VoidCallback? minimize,
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
                onMinimize: minimize ?? () {},
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
    testWidgets('caller controls are two rows of three in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        ),
      );
      var ended = 0;
      var minimized = 0;
      await tester.pumpWidget(
        host(theme, end: () => ended++, minimize: () => minimized++),
      );
      await tester.pump();
      final mute = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final camera = tester.getCenter(find.byIcon(Icons.videocam_off_rounded));
      final share = tester.getCenter(find.byIcon(Icons.screen_share_rounded));
      final speaker = tester.getCenter(find.byIcon(Icons.hearing_rounded));
      final end = tester.getCenter(find.byIcon(Icons.call_end_rounded));
      final minimize = tester.getCenter(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
      );
      // Row one: Camera · Screen Share · Speaker.
      expect(camera.dy, closeTo(share.dy, 0.5));
      expect(share.dy, closeTo(speaker.dy, 0.5));
      expect(camera.dx, lessThan(share.dx));
      expect(share.dx, lessThan(speaker.dx));
      // Row two, under it: Minimize · End · Mute, column for column.
      expect(minimize.dy, closeTo(end.dy, 0.5));
      expect(end.dy, closeTo(mute.dy, 0.5));
      expect(end.dy, greaterThan(share.dy));
      expect(minimize.dx, closeTo(camera.dx, 0.5));
      expect(end.dx, closeTo(share.dx, 0.5));
      expect(mute.dx, closeTo(speaker.dx, 0.5));
      // Grouped with one fixed gap, not spread across the screen.
      expect(share.dx - camera.dx, closeTo(speaker.dx - share.dx, 0.5));
      expect(share.dx - camera.dx, lessThan(390 / 3 - 4));
      expect(share.dx, closeTo(390 / 2, 0.5));
      expect(find.text('Minimize'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      expect(minimized, 1);
      // The encrypted line sits over the deck.
      final label = tester.getRect(find.text('End-to-end encrypted'));
      expect(label.bottom, lessThan(camera.dy));
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
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
    });
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
      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      final mute = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final end = tester.getCenter(find.byIcon(Icons.call_end_rounded));
      // Minimize is the top chevron here, not a seat in the strip.
      final chevron = tester.getCenter(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
      );
      expect(chevron.dx, lessThan(size.width * 0.5));
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
  for (final size in const [
    Size(320, 480),
    Size(360, 640),
    Size(412, 915),
    Size(800, 1280),
  ]) {
    for (final scale in const [1.0, 1.6]) {
      testWidgets('portrait deck fits $size at text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          host(ThemeData(), size: size, scale: scale, lang: 'bn'),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final camera = tester.getRect(find.byIcon(Icons.videocam_off_rounded));
        final speaker = tester.getRect(find.byIcon(Icons.hearing_rounded));
        final end = tester.getRect(find.byIcon(Icons.call_end_rounded));
        // Inside the screen, and clear of the caller's name above.
        expect(camera.left, greaterThan(8));
        expect(speaker.right, lessThan(size.width - 8));
        expect(end.bottom, lessThan(size.height));
        // Lifted off the bottom edge, label and all.
        expect(
          tester.getRect(find.text('শেষ করুন')).bottom,
          lessThan(size.height - 24),
        );
        expect(camera.top, greaterThan(size.height * 0.5));
        debugPrint(
          'ICONS ${tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon?.codePoint.toRadixString(16)).toList()} lock=${Icons.lock_rounded.codePoint.toRadixString(16)}',
        );
        final lock = tester.getRect(find.byIcon(Icons.lock_rounded));
        expect(lock.top, greaterThan(size.height * 0.4));
        expect(lock.bottom, lessThan(camera.top));
        // Never below a comfortable touch target.
        final seat = tester.getSize(
          find
              .ancestor(
                of: find.byIcon(Icons.call_end_rounded),
                matching: find.byType(ClipOval),
              )
              .first,
        );
        expect(seat.width, greaterThanOrEqualTo(48));
        expect(seat.width, lessThanOrEqualTo(104));
        // Scales with the screen: a fifth of the width where there is room.
        if (size.height >= 800 && scale == 1.0) {
          expect(
            seat.width,
            closeTo((size.width * 0.2).clamp(56.0, 104.0), 0.5),
          );
        }
      });
    }
  }

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

  testWidgets('portrait has one minimize control, the deck seat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(ThemeData()));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });
}
