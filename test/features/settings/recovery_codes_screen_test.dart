import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/settings/recovery-codes/recovery_codes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../messages/recovery_session_test.dart'
    show MemoryRecoveryStorage, MemoryRecoveryRepo, MemoryRecoveryApi;

class _OfflineRepo extends MemoryRecoveryRepo {
  _OfflineRepo(super.store);
  @override
  Future<Map<String, dynamic>> getE2eeVault() async =>
      throw StateError('offline: viewing must not need the server');
}

void main() {
  testWidgets(
    'saved code shows offline without email and hides on background',
    (tester) async {
      final store = MemoryRecoveryStorage();
      final repo = _OfflineRepo(store);
      final vault = MessageVault(repo, store);
      await tester.runAsync(
        () => vault.startSession(
          userId: 'u',
          api: MemoryRecoveryApi(store, repo),
        ),
      );
      final code = (await vault.readStoredRecoveryCode())!;
      Future<void> open() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLanguageProvider.overrideWithValue('en'),
              messageVaultProvider.overrideWithValue(vault),
            ],
            child: const MaterialApp(home: RecoveryCodesScreen()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text(code), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Email me a code'), findsNothing);
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
      await tester.tap(find.text('Show code'));
      await tester.pumpAndSettle();
      expect(find.text(code), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(find.text(code), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
