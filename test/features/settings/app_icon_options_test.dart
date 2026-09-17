import 'package:ababilx/features/settings/app-icon/app_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picker offers default plus calendar, calculator, notes disguises', () {
    expect(appIconOptions.map((o) => o.id).toList(), [
      'default',
      'calendar',
      'calculator',
      'notes',
    ]);
  });

  test('branded night/ember/pulse marks are not in the picker', () {
    expect(
      appIconOptions.map((o) => o.id),
      isNot(containsAll(['night', 'ember', 'pulse'])),
    );
  });
}
