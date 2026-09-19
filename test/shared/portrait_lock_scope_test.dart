import 'package:ababilx/shared/widgets/portrait_lock_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(PortraitLockScope.debugResetDepth);

  testWidgets('locks portrait on mount and unlocks on dispose', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PortraitLockScope(child: SizedBox())),
    );
    expect(PortraitLockScope.debugDepth, 1);
    expect(
      // SystemChrome has no getter; assert the constants the scope uses so a
      // future edit that drops portraitDown still fails this pin.
      PortraitLockScope.locked,
      containsAll([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
    expect(PortraitLockScope.unlocked, DeviceOrientation.values);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(PortraitLockScope.debugDepth, 0);
  });

  testWidgets('nested scopes stay locked until the last one leaves', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PortraitLockScope(child: PortraitLockScope(child: SizedBox())),
      ),
    );
    expect(PortraitLockScope.debugDepth, 2);

    await tester.pumpWidget(
      const MaterialApp(home: PortraitLockScope(child: SizedBox())),
    );
    await tester.pump();
    expect(PortraitLockScope.debugDepth, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(PortraitLockScope.debugDepth, 0);
  });
}
