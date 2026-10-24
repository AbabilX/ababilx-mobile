import '../../local-backup/ui/restore_account_backup_card.dart';
import '../../transfer-chats/ui/transfer_chats_card.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/network/recent_sign_in.dart';
import '../../auth/providers/auth_provider.dart';
import '../../policy/policy_precheck.dart';
import '../../policy/widgets/policy_accept_card.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/chat_repository.dart';
import '../data/chat_recovery_api.dart';
import '../providers/chat_provider.dart';
import 'message_vault.dart';
import 'message_entry_ready.dart';
import 'new_chat_setup.dart';
import 'vault_gate_recovery_choice.dart';

/// The one post-login decision screen; restore continues in chat after unlock.
class MessageRecoveryScreen extends ConsumerStatefulWidget {
  const MessageRecoveryScreen({super.key});
  @override
  ConsumerState<MessageRecoveryScreen> createState() => _State();
}

class _State extends ConsumerState<MessageRecoveryScreen> {
  bool _checking = true, _busy = false;
  bool _needsPolicy = false;
  String? _error;
  bool _signOutToContinue = false;
  Map<String, dynamic>? _public;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  /// Policy first: this route sits outside the shell and its policy card, and
  /// the gate 403s every call below. (A phone holding its key never gets
  /// here on launch — see `tryQuietMessageEntry`.)
  Future<void> _start() async {
    if (await policyPending(ref)) {
      if (mounted) setState(() => _needsPolicy = true);
      return;
    }
    await _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      _userId = await ref.read(chatProvider.notifier).ensureCurrentUserId();
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
        // A failed request does not invalidate this phone's trusted key.
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
      if (mounted) setState(() => _checking = false);
    } catch (error) {
      if (!mounted) return;
      // A cached profile can predate a policy bump; read the refusal too.
      if (isPolicyRefusal(error)) {
        setState(() => _needsPolicy = true);
        return;
      }
      final signIn =
          error is RecentSignInRequired &&
          error.outcome != ReauthOutcome.unavailable;
      setState(() {
        _checking = false;
        _error = signIn ? 'sign_in_again_to_continue' : 'recovery_check_failed';
        _signOutToContinue =
            signIn && error.outcome == ReauthOutcome.notSupported;
      });
    }
  }

  void _finish() => ref.read(messageEntryReadyProvider.notifier).state = true;

  void _newSession() {
    if (_busy) return;
    _busy = true;
    ref
        .read(newChatSetupProvider.notifier)
        .start(userId: _userId, expectedPublicKey: _public);
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    ref.listen(profileProvider, (_, next) {
      if (!_needsPolicy || next.valueOrNull?.acceptPolicy != true) return;
      setState(() => _needsPolicy = false);
      unawaited(_check());
    });
    // No shell under this route, so the card gets its own surface.
    if (_needsPolicy) return const Scaffold(body: PolicyAcceptCard());
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
                          // Signing out keeps the archive and the pending
                          // key, which is committed after the next sign-in.
                          onPressed: _signOutToContinue
                              ? ref.read(authProvider.notifier).signOut
                              : _check,
                          child: Text(
                            t(
                              _signOutToContinue
                                  ? 'sign_in_again'
                                  : 'recovery_retry',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : VaultGateRecoveryChoice(
                  busy: _busy,
                  onStartFresh: _newSession,
                  backupOption: localBackupAccountOption(
                    busy: _busy,
                    onStartFresh: _newSession,
                  ),
                  // The key arrived with the chats: the check finds it held.
                  transferOption: transferChatsOption(
                    busy: _busy,
                    onDone: () => unawaited(_check()),
                  ),
                ),
        ),
      ),
    );
  }
}
