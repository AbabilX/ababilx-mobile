import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/calls/call_store_sync.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/providers/voice_call_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _LoggedOutAuth extends AuthNotifier {
  @override
  Future<bool> build() async => false;
}

VoiceCallState _connectedState() => VoiceCallState(
  phase: VoiceCallPhase.connected,
  currentUserId: 'me',
  connectedAt: DateTime(2026, 9, 14),
  call: VoiceCall(
    id: 'call-1',
    teamId: '',
    conversationId: 'conversation-1',
    callerId: 'me',
    calleeId: 'peer',
    status: 'accepted',
    callerName: 'Me',
    calleeName: 'Peer',
    expiresAt: DateTime(2026, 9, 15),
    createdAt: DateTime(2026, 9, 14),
  ),
);

class _ConnectedCall extends VoiceCallNotifier {
  @override
  VoiceCallState build() => _connectedState();

  @override
  Future<void> onAppLifecycle(AppLifecycleState lifecycle) async {}

  @override
  Future<void> syncFromNativeIncoming() async {}

  @override
  Future<void> ensureNativeIncomingUi({bool force = false}) async {}
}

class _IdleThenConnectedCall extends _ConnectedCall {
  @override
  VoiceCallState build() => const VoiceCallState(currentUserId: 'me');

  void connect() => state = _connectedState();
}

void main() {
  testWidgets('a minimized connected call stays minimized after app resume', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/call',
      routes: [
        GoRoute(path: '/call', builder: (_, _) => const Text('call')),
        GoRoute(path: '/messages', builder: (_, _) => const Text('messages')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_LoggedOutAuth.new),
          voiceCallProvider.overrideWith(_ConnectedCall.new),
        ],
        child: CallStoreSync(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/call');

    // This is the in-call minimize action's observable result.
    router.go('/messages');
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/messages');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      router.state.matchedLocation,
      '/messages',
      reason: 'Resume must not undo the user\'s minimize decision.',
    );
  });

  testWidgets('a genuinely new foreground call still opens the call screen', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/messages',
      routes: [
        GoRoute(path: '/call', builder: (_, _) => const Text('call')),
        GoRoute(path: '/messages', builder: (_, _) => const Text('messages')),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedOutAuth.new),
        voiceCallProvider.overrideWith(_IdleThenConnectedCall.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CallStoreSync(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    (container.read(voiceCallProvider.notifier) as _IdleThenConnectedCall)
        .connect();
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/call');
  });
}
