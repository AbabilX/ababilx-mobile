import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../data/chat_repository.dart';
import '../data/chat_recovery_api.dart';
import '../providers/chat_provider.dart';
import '../archive/archive_provider.dart';
import 'message_vault.dart';
import 'message_entry_ready.dart';
import 'new_chat_setup.dart';
import 'vault_gate_recovery_choice.dart';
import 'vault_gate_recovery_code.dart';

/// The one post-login decision screen. New sessions never show an OTP or a
/// save-code screen. Restore continues in chat once the identity is unlocked.
class MessageRecoveryScreen extends ConsumerStatefulWidget {
  const MessageRecoveryScreen({super.key});
  @override
  ConsumerState<MessageRecoveryScreen> createState() => _State();
}

class _State extends ConsumerState<MessageRecoveryScreen> {
  bool _checking = true, _busy = false, _enterCode = false;
  String? _error;
  Map<String, dynamic>? _public;
  bool _hasRecovery = false;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final chat = ref.read(chatProvider.notifier);
      _userId = await chat.ensureCurrentUserId();
      if (!mounted) return;
      final vault = ref.read(messageVaultProvider);
      final api = ref.read(chatRecoveryApiProvider);
      if (await vault.resumePendingSession(_userId, api)) {
        if (mounted) _finish();
        return;
      }
      Map<String, dynamic> status;
      try {
        status = await ref.read(chatRepositoryProvider).getE2eeVault();
      } catch (_) {
        // A failed status request does not invalidate this phone's trusted key.
        if (await vault.restoreTrustedIdentityOffline()) {
          if (mounted) _finish();
          return;
        }
        rethrow;
      }
      if (!mounted) return;
      if (status['exists'] != true) {
        await vault.startSession(userId: _userId, api: api);
        if (mounted) _finish();
        return;
      }
      final remote = Map<String, dynamic>.from(status['vault'] as Map);
      _public = Map<String, dynamic>.from(remote['public_key'] as Map);
      if (await vault.adoptCurrentIdentity(_public!)) {
        if (mounted) _finish();
        return;
      }
      if (!mounted) return;
      if (status['has_history'] == false) {
        await vault.startSession(
          userId: _userId,
          api: api,
          expectedPublicKey: _public,
        );
        if (mounted) _finish();
        return;
      }
      if (mounted) {
        setState(() {
          _hasRecovery = status['has_recovery'] == true;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'recovery_check_failed';
        });
      }
    }
  }

  void _finish() {
    ref.read(messageEntryReadyProvider.notifier).state = true;
  }

  void _newSession() {
    if (_busy) return;
    _busy = true;
    ref
        .read(newChatSetupProvider.notifier)
        .start(userId: _userId, expectedPublicKey: _public);
    _finish();
  }

  Future<void> _recovered() async {
    // Persist the restore intent before navigating, so a killed app resumes.
    await ref.read(chatProvider.notifier).markHistoryRestorePending();
    if (!mounted) return;
    await ref.read(archiveProvider.notifier).markRecoveryPending();
    if (!mounted) return;
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: _checking
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(t('recovery_checking')),
                    ],
                  ),
                )
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t(_error!), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _check,
                          child: Text(t('recovery_retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : _enterCode
              ? VaultGateRecoveryCode(
                  onUnlocked: _recovered,
                  onBack: () => setState(() => _enterCode = false),
                )
              : VaultGateRecoveryChoice(
                  busy: _busy,
                  hasRecovery: _hasRecovery,
                  onRecover: () => setState(() => _enterCode = true),
                  onStartFresh: _newSession,
                ),
        ),
      ),
    );
  }
}
