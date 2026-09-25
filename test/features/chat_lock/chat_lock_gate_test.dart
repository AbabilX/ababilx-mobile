import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/chat-lock/data/chat_lock_index.dart';
import 'package:ababilx/features/chat-lock/data/chat_lock_secrets.dart';
import 'package:ababilx/features/chat-lock/providers/chat_lock_session.dart';
import 'package:ababilx/features/chat-lock/widgets/chat_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget app(ProviderContainer container, Widget child) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      );

  testWidgets('a locked chat is not built until its password is given', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await ChatLockIndex.write({'c1': ChatLockMethod.password});
      await ChatLockSecrets.setPassword('c1', 'open sesame');
    });
    final container = ProviderContainer(
      overrides: [appLanguageProvider.overrideWithValue('en')],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      app(
        container,
        const ChatLockGate(
          conversationId: 'c1',
          relockOnLeave: true,
          child: Text('the conversation'),
        ),
      ),
    );
    expect(find.text('the conversation'), findsNothing);
    expect(find.text('This chat is locked'), findsOneWidget);

    Future<void> tryPassword(String password, bool Function() done) async {
      await tester.enterText(find.byType(TextField), password);
      await tester.runAsync(() async {
        await tester.tap(find.text('Unlock'));
        // PBKDF2 runs on a real isolate, outside the fake clock.
        for (var i = 0; i < 50 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();
    }

    await tryPassword(
      'wrong',
      () => find.text('Wrong password').evaluate().isNotEmpty,
    );
    expect(find.text('the conversation'), findsNothing);
    expect(find.text('Wrong password'), findsOneWidget);

    await tryPassword(
      'open sesame',
      () => container.read(chatLockSessionProvider).isOpen('c1'),
    );
    expect(find.text('the conversation'), findsOneWidget);

    // Leaving the chat locks it again.
    await tester.pumpWidget(app(container, const SizedBox()));
    await tester.pump();
    expect(container.read(chatLockSessionProvider).isOpen('c1'), isFalse);
  });

  testWidgets('an unlocked chat passes straight through', (tester) async {
    await tester.runAsync(() => ChatLockIndex.write({}));
    final container = ProviderContainer(
      overrides: [appLanguageProvider.overrideWithValue('en')],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      app(
        container,
        const ChatLockGate(conversationId: 'c1', child: Text('open chat')),
      ),
    );
    expect(find.text('open chat'), findsOneWidget);
  });
}
