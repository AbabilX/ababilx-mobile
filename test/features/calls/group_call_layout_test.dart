import 'package:ababilx/features/calls/group/call-ui/call_round_button.dart';
import 'package:ababilx/features/calls/group/call-ui/call_tile_grid.dart';
import 'package:ababilx/features/calls/group/call-ui/call_stage_view.dart';
import 'package:ababilx/features/calls/group/call-ui/group_call_stage.dart';
import 'package:ababilx/features/calls/group/call-ui/participant_tile.dart';
import 'package:ababilx/features/calls/group/call_icons.dart';
import 'package:ababilx/features/calls/group/providers/group_call_state.dart';
import 'package:ababilx/shared/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout regressions the group call screen actually shipped with: a control
/// bar that wrapped onto two lines and orphaned Hang up, a grid that left dead
/// space under a solo call, a fixed 62dp avatar in a screen-wide tile, and a
/// name chip stretched edge to edge.

Widget _host({required double width, required double height, required Widget child}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

List<Widget> _controls(double diameter) => [
  for (final icon in [
    CallIcons.micOn,
    CallIcons.speakerOn,
    CallIcons.screenShare,
    CallIcons.raiseHand,
    CallIcons.reaction,
    CallIcons.leave,
  ])
    CallRoundButton(
      diameter: diameter,
      icon: icon,
      label: 'control',
      onTap: () {},
    ),
];

const _participant = GroupParticipantView(
  identity: 'u1',
  name: 'Murad',
  isLocal: true,
  isSpeaking: false,
  isMuted: false,
);

void main() {
  group('control bar', () {
    testWidgets('keeps six controls on one row on a 412dp phone', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 388,
          height: 120,
          child: CallControlBar(count: 6, builder: _controls),
        ),
      );
      expect(tester.takeException(), isNull);

      final buttons = tester.widgetList<CallRoundButton>(
        find.byType(CallRoundButton),
      );
      expect(buttons.length, 6);

      final tops = <double>{
        for (var i = 0; i < 6; i++)
          tester.getTopLeft(find.byType(CallRoundButton).at(i)).dy,
      };
      expect(tops.length, 1, reason: 'wrapped onto a second line');
    });

    testWidgets('shrinks the controls rather than wrapping on a narrow phone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: 300,
          height: 120,
          child: CallControlBar(count: 6, builder: _controls),
        ),
      );
      expect(tester.takeException(), isNull);

      final first = tester.widget<CallRoundButton>(
        find.byType(CallRoundButton).first,
      );
      expect(first.diameter, lessThan(callButtonDiameter));
      expect(first.diameter, greaterThanOrEqualTo(callButtonMinDiameter));
    });
  });

  group('tile grid', () {
    testWidgets('a solo tile fills the stage', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 400,
          height: 600,
          child: CallTileGrid(
            count: 1,
            tileBuilder: (_) => const ColoredBox(key: Key('t0'), color: Colors.red),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('t0'))), const Size(400, 600));
    });

    testWidgets('a short last row is centred', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 400,
          height: 600,
          child: CallTileGrid(
            count: 3,
            tileBuilder: (index) =>
                ColoredBox(key: Key('t$index'), color: Colors.red),
          ),
        ),
      );
      final last = tester.getRect(find.byKey(const Key('t2')));
      final host = tester.getRect(find.byType(CallTileGrid));
      expect(last.center.dx, closeTo(host.center.dx, 0.5));
    });
  });

  group('speaker view', () {
    testWidgets('the speaker tile fills the stage width', (tester) async {
      const others = [
        GroupParticipantView(
          identity: 'u2',
          name: 'Rafi',
          isLocal: false,
          isSpeaking: false,
          isMuted: false,
        ),
      ];
      await tester.pumpWidget(
        _host(
          width: 400,
          height: 600,
          child: const GroupCallStage(
            state: GroupCallState(
              phase: GroupCallPhase.connected,
              participants: [_participant, ...others],
            ),
            view: CallStageView.speaker,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // The big tile, not one of the 96dp filmstrip tiles below it.
      final widest = find
          .byType(ParticipantTile)
          .evaluate()
          .map((element) => tester.getSize(find.byWidget(element.widget)).width)
          .reduce((a, b) => a > b ? a : b);
      expect(widest, 400);
    });
  });

  group('participant tile', () {
    testWidgets('scales the avatar to the tile instead of a fixed 62dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: 360,
          height: 560,
          child: ParticipantTile(participant: _participant),
        ),
      );
      final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
      expect(avatar.size, greaterThan(100));
    });

    testWidgets('the name chip hugs its text', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 360,
          height: 560,
          child: ParticipantTile(participant: _participant),
        ),
      );
      final chip = tester.getSize(find.byKey(callNameChipKey)).width;
      expect(chip, lessThan(180), reason: 'chip stretched across the tile');
    });
  });
}
