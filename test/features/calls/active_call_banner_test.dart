import 'package:ababilx/features/calls/group/providers/group_call_provider.dart';
import 'package:ababilx/features/calls/widgets/active_call_banner.dart';
import 'package:ababilx/features/calls/widgets/call_return_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The banner wraps go_router's navigator, which carries a `GlobalObjectKey`.
/// Swapping between "bare child" and "child inside a Column" moved that key
/// between parents mid-frame and crashed the app on every hangup. Its subtree
/// shape has to stay constant whatever the call is doing.

class _FakeGroupCall extends GroupCallNotifier {
  @override
  GroupCallState build() => const GroupCallState();

  void setPhase(GroupCallPhase phase) => state = GroupCallState(phase: phase);
}

/// Stands in for the navigator: a `GlobalKey` state that must survive.
class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('never reparents the navigator when a call starts or ends', (
    tester,
  ) async {
    final probeKey = GlobalKey<_ProbeState>();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const Text('home'))],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupCallProvider.overrideWith(_FakeGroupCall.new)],
        child: MaterialApp(
          home: ActiveCallBanner(
            router: router,
            child: _Probe(key: probeKey),
          ),
        ),
      ),
    );

    final call =
        ProviderScope.containerOf(
              tester.element(find.byKey(probeKey)),
            ).read(groupCallProvider.notifier)
            as _FakeGroupCall;

    // The invariant is the SHAPE, not the state: a GlobalKey preserves its
    // State across a reparent, so asserting on the State would pass either
    // way. What crashed was the child changing parents at all, so assert it
    // sits under the same Expanded whatever the call is doing.
    Finder wrapper() => find.ancestor(
      of: find.byKey(probeKey),
      matching: find.byType(Expanded),
    );

    expect(wrapper(), findsOneWidget);

    call.setPhase(GroupCallPhase.connected);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(wrapper(), findsOneWidget);
    expect(find.byType(CallReturnBar), findsOneWidget);

    call.setPhase(GroupCallPhase.idle);
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Bar gone, but the child has not moved — that move is what crashed on
    // every hangup.
    expect(find.byType(CallReturnBar), findsNothing);
    expect(wrapper(), findsOneWidget);
  });
}
