// Regression assertions for personal group-call lifecycle ownership.
// Fakes isolate app-level ownership; they do not simulate native audio.
import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/calls/group/group_call_sync.dart';
import 'package:ababilx/features/calls/group/providers/group_call_provider.dart';
import 'package:ababilx/features/calls/widgets/active_call_banner.dart';
import 'package:ababilx/features/calls/widgets/call_return_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth extends AuthNotifier {
  @override
  Future<bool> build() async => true;

  void loading() => state = const AsyncLoading();
  void logout() => state = const AsyncData(false);
}

class _Call extends GroupCallNotifier {
  int boots = 0;
  int shutdowns = 0;

  @override
  GroupCallState build() => GroupCallState(phase: ref.read(_initialPhase));

  @override
  Future<void> bootstrap() async => boots++;

  @override
  Future<void> shutdown() async {
    shutdowns++;
    state = const GroupCallState();
  }
}

final _initialPhase = Provider((ref) => GroupCallPhase.idle);

Future<(_Call, ProviderContainer)> mount(
  WidgetTester tester, {
  bool connected = false,
}) async {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
  );
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      groupCallProvider.overrideWith(_Call.new),
      _initialPhase.overrideWithValue(
        connected ? GroupCallPhase.connected : GroupCallPhase.idle,
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: GroupCallSync(
        router: router,
        child: MaterialApp(
          home: ActiveCallBanner(router: router, child: const SizedBox()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (container.read(groupCallProvider.notifier) as _Call, container);
}

void main() {
  testWidgets('transient auth loading preserves the call, logout ends it', (
    tester,
  ) async {
    final (call, container) = await mount(tester, connected: true);
    final auth = container.read(authProvider.notifier) as _Auth;
    auth.loading();
    await tester.pump();
    await tester.pump();
    expect(call.shutdowns, 0);
    expect(find.byType(CallReturnBar), findsOneWidget);
    auth.logout();
    await tester.pump();
    await tester.pump();
    expect(call.shutdowns, 1);
    expect(find.byType(CallReturnBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('personal group calls bootstrap without workspace membership', (
    tester,
  ) async {
    final (call, _) = await mount(tester);
    expect(
      call.boots,
      1,
      reason: 'Personal group calls must receive lifecycle/native events.',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
