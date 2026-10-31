import 'package:ababilx/core/network/ws_link_up_provider.dart';
import 'package:ababilx/features/messages/chat-list/brand_title.dart';
import 'package:ababilx/shared/widgets/shimmer_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Link extends WsLinkUpNotifier {
  _Link(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  void set(bool up) => state = up;
}

Future<_Link> _pump(
  WidgetTester tester, {
  required bool up,
  bool still = false,
}) async {
  final link = _Link(up);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [wsLinkUpProvider.overrideWith(() => link)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: const Scaffold(body: ChatListBrandTitle()),
        ),
      ),
    ),
  );
  return link;
}

/// [WidgetTester.pumpAndSettle] throws if an animation keeps asking for frames.
Future<void> _expectStill(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(tester.binding.hasScheduledFrame, isFalse);
}

void main() {
  testWidgets('connected: plain title, nothing animating', (tester) async {
    await _pump(tester, up: true);
    expect(find.text('AbabilX'), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    await _expectStill(tester);
  });

  testWidgets('reconnecting: the title shimmers until the socket is back', (
    tester,
  ) async {
    final link = await _pump(tester, up: true);

    link.set(false);
    await tester.pump();
    expect(find.text('AbabilX'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);

    link.set(true);
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
    await _expectStill(tester);
  });

  testWidgets('opening while down starts the shimmer at once', (tester) async {
    await _pump(tester, up: false);
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: dimmed, still, nothing animating', (
    tester,
  ) async {
    await _pump(tester, up: false, still: true);
    expect(find.byType(ShaderMask), findsNothing);
    final dim = tester.widget<Opacity>(find.byType(Opacity));
    expect(dim.opacity, lessThan(1));
    await _expectStill(tester);
  });

  test('the sweep crosses the whole word and starts off it', () {
    expect(shimmerSweepDx(0, 100), -100);
    expect(shimmerSweepDx(0.5, 100), 0);
    expect(shimmerSweepDx(1, 100), 100);
  });
}
