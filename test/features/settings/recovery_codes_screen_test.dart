import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/features/messages/data/chat_recovery_api.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/settings/recovery-codes/recovery_codes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../messages/recovery_session_test.dart'
    show MemoryRecoveryStorage, MemoryRecoveryRepo, MemoryRecoveryApi;

class _Api extends ChatRecoveryApi {
  _Api(MemoryRecoveryStorage store, this.public) : super(ApiClient(store));
  final Map<String, dynamic> public;
  int challenges = 0, verifications = 0;
  @override
  Future<Map<String, dynamic>> challenge() async {
    challenges++;
    return {
      'challenge_id': 'challenge-$challenges',
      'email': 'm****@mail.com',
      'retry_after': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> verify(String challenge, String code) async {
    verifications++;
    if (code != 'ABC123456') throw StateError('wrong code');
    return {'verified': true, 'public_key': public};
  }
}

void main() {
  testWidgets(
    'only reveals after email verification; reopening requires another challenge',
    (tester) async {
      final store = MemoryRecoveryStorage();
      final repo = MemoryRecoveryRepo(store);
      final vault = MessageVault(repo, store);
      await tester.runAsync(
        () => vault.startSession(
          userId: 'u',
          api: MemoryRecoveryApi(store, repo),
        ),
      );
      final api = _Api(store, vault.publicIdentity!);
      final code = await tester.runAsync(
        () => vault.readVerifiedRecoveryCode({
          'verified': true,
          'public_key': vault.publicIdentity,
        }),
      );
      Future<void> open() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLanguageProvider.overrideWithValue('en'),
              chatRecoveryApiProvider.overrideWithValue(api),
              messageVaultProvider.overrideWithValue(vault),
            ],
            child: const MaterialApp(home: RecoveryCodesScreen()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text(code!), findsNothing);
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.scrollUntilVisible(
        find.text('Verify and view code'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Verify and view code'));
      await tester.pumpAndSettle();
      expect(find.text(code), findsNothing);
      await tester.enterText(find.byType(TextField), 'ABC123456');
      await tester.scrollUntilVisible(
        find.text('Verify and view code'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Verify and view code'));
      await tester.pumpAndSettle();
      expect(find.text(code), findsOneWidget);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.text(code), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(find.text(code), findsNothing);
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();
      expect(api.challenges, 2);
      expect(api.verifications, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
