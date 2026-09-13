import 'dart:io';
import 'dart:ui' as ui;

import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/core/theme/theme_seed.dart';
import 'package:ababilx/features/calls/group/data/models/group_call.dart';
import 'package:ababilx/features/calls/group/group_call_status.dart';
import 'package:ababilx/features/calls/group/providers/group_call_provider.dart';
import 'package:ababilx/features/calls/group/screens/group_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call extends GroupCallNotifier {
  @override
  GroupCallState build() => GroupCallState(
    phase: GroupCallPhase.connected,
    call: GroupCall.fromJson({
      'id': 'call',
      'conversation_id': 'group',
      'conversation_name': 'Design team · Weekly catch-up',
    }),
    participants: [
      for (final name in ['Murad', 'Tanvir', 'Ayesha', 'Sara'])
        GroupParticipantView(
          identity: name,
          name: name,
          isLocal: name == 'Murad',
          isSpeaking: name == 'Tanvir',
          isMuted: name == 'Sara',
        ),
    ],
  );

  void reconnect() => state = state.copyWith(reconnecting: true);
}

void main() {
  for (final size in [const Size(320, 640), const Size(640, 360)]) {
    testWidgets('group screen fits $size with scaled Bengali text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          groupCallProvider.overrideWith(_Call.new),
          appLanguageProvider.overrideWithValue('bn'),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(colorScheme: ThemeSeed.scheme(Brightness.light)),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width < 400 ? 2 : 1.3),
              ),
              child: child!,
            ),
            home: const GroupCallScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      (container.read(groupCallProvider.notifier) as _Call).reconnect();
      await tester.pump();
      expect(
        find.text(AppTranslations.of('bn', 'call_reconnecting')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('status does not claim a reconnecting caller has left', () {
    const state = GroupCallState(
      phase: GroupCallPhase.connected,
      reconnecting: true,
    );
    expect(state.active, isTrue);
    expect(groupCallStatus(state, 'en'), 'Reconnecting…');
    expect(
      groupCallStatus(state.copyWith(reconnecting: false, muted: true), 'en'),
      'Waiting for others · You are muted',
    );
  });

  // Optional visual capture from real widgets; no server/native call is started.
  testWidgets('render group screen preview', (tester) async {
    const output = String.fromEnvironment('CALL_UI_PREVIEW');
    if (output.isEmpty) return;
    await tester.runAsync(() async {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            const String.fromEnvironment('CALL_UI_FONT'),
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
    });
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupCallProvider.overrideWith(_Call.new),
          appLanguageProvider.overrideWithValue('en'),
        ],
        child: MaterialApp(
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ThemeSeed.scheme(Brightness.dark),
          ),
          home: RepaintBoundary(key: key, child: const GroupCallScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
