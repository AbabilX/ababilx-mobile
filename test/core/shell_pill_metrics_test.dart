import 'package:ababilx/core/router/shell_bottom_bar/shell_pill_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The floating nav bar sits inside a SafeArea, so what it actually occupies
/// is its own height plus whatever the system reserves at the bottom. A list
/// padded by the constant alone hides its last row under the pill on every
/// gesture-navigation phone.
void main() {
  Future<double> measure(WidgetTester tester, double bottomInset) async {
    late double value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: bottomInset)),
        child: Builder(
          builder: (context) {
            value = ShellPillMetrics.contentBottom(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  testWidgets('three-button navigation gets the bare constant', (tester) async {
    expect(await measure(tester, 0), ShellPillMetrics.contentBottomInset);
  });

  testWidgets('gesture navigation is padded past the handle', (tester) async {
    expect(await measure(tester, 34), ShellPillMetrics.contentBottomInset + 34);
  });

  testWidgets('content always clears the bar itself', (tester) async {
    // The bar draws inside SafeArea with 12 of its own padding under a
    // 64-high pill; anything less than that and the last row is covered.
    const barOccupies = ShellPillMetrics.height + 12;
    for (final inset in [0.0, 24.0, 48.0]) {
      expect(
        await measure(tester, inset),
        greaterThan(barOccupies + inset),
        reason: 'bottom inset $inset',
      );
    }
  });
}
