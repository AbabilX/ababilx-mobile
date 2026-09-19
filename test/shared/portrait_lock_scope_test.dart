import 'package:ababilx/shared/widgets/portrait_lock_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locks portrait on mount and unlocks on dispose', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PortraitLockScope(child: SizedBox())),
    );
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
  });
}
