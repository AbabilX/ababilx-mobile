import 'package:ababilx/features/calls/group/call-ui/call_round_button.dart';
import 'package:ababilx/features/calls/group/call_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The control bar shipped broken twice: as a [Wrap] that broke six controls
/// onto two rows and orphaned Hang up, then as one row of 58dp circles spread
/// edge to edge over the bare backdrop with no bar behind them.

Widget _host({
  required double width,
  required double height,
  required Widget child,
}) => MaterialApp(
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

void main() {
  group('control bar', () {
    testWidgets('groups the controls in a pill that hugs them', (tester) async {
      // The disconnected state is Leave on its own. It used to draw a bare
      // 58dp circle in the middle of the backdrop; the pill has to shrink to
      // it rather than stretching across the screen.
      await tester.pumpWidget(
        _host(
          width: 388,
          height: 120,
          child: CallControlBar(
            count: 1,
            builder: (diameter) => [_controls(diameter).last],
          ),
        ),
      );

      final pill = tester.getRect(find.byType(DecoratedBox).last);
      final button = tester.getRect(find.byType(CallRoundButton));
      expect(pill.width, lessThan(120));
      // Padding on every side, so the button never touches the pill's edge.
      expect(button.left - pill.left, greaterThan(4));
      expect(pill.right - button.right, greaterThan(4));
      expect(button.top - pill.top, greaterThan(4));
    });

    testWidgets('leaves a margin either side of a full row', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 388,
          height: 120,
          child: CallControlBar(count: 6, builder: _controls),
        ),
      );

      final host = tester.getRect(find.byType(CallControlBar));
      final pill = tester.getRect(find.byType(DecoratedBox).last);
      expect(pill.width, lessThan(host.width));
      expect(pill.center.dx, closeTo(host.center.dx, 0.5));
    });

    testWidgets('keeps six controls on one row on a 412dp phone', (
      tester,
    ) async {
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
}
