import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/messages/message_e2ee/message_entry_ready.dart';
import 'package:ababilx/features/share_intake/data/share_intake_channel.dart';
import 'package:ababilx/features/share_intake/providers/share_intake_provider.dart';
import 'package:ababilx/features/share_intake/share_intake_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SignedInAuth extends AuthNotifier {
  @override
  Future<bool> build() async => true;
}

class _InitialTextShare extends ShareIntakeChannel {
  const _InitialTextShare();

  @override
  Future<String?> initialShare() async =>
      '{"text":"https://example.com/post","files":[]}';

  @override
  Stream<String> shares() => const Stream.empty();

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('a ready signed-in app opens the share destination', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/messages',
      routes: [
        GoRoute(path: '/messages', builder: (_, _) => const Text('messages')),
        GoRoute(path: '/share', builder: (_, _) => const Text('share target')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedInAuth.new),
          messageEntryReadyProvider.overrideWith((ref) => true),
          shareIntakeChannelProvider.overrideWithValue(
            const _InitialTextShare(),
          ),
        ],
        child: ShareIntakeSync(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/share');
    expect(find.text('share target'), findsOneWidget);
  });
}
