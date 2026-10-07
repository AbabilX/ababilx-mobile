import 'package:ababilx/core/router/shell_bottom_bar/nav_double_tap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 7, 12);

  test('two quick taps are a double tap, a slow pair is not', () {
    final taps = NavDoubleTap();
    expect(taps.hit(t0), isFalse);
    expect(taps.hit(t0.add(const Duration(milliseconds: 200))), isTrue);

    expect(taps.hit(t0.add(const Duration(seconds: 2))), isFalse);
    expect(taps.hit(t0.add(const Duration(seconds: 3))), isFalse);
  });

  test('a third quick tap starts over instead of firing again', () {
    final taps = NavDoubleTap();
    taps.hit(t0);
    expect(taps.hit(t0.add(const Duration(milliseconds: 100))), isTrue);
    expect(taps.hit(t0.add(const Duration(milliseconds: 200))), isFalse);
  });
}
