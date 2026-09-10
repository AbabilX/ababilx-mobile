import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../providers/chat_provider.dart';
import 'message_vault.dart';
import 'vault_gate_error.dart';
import 'vault_gate_recovery_code.dart';
import 'vault_gate_recovery_choice.dart';
import '../data/chat_recovery_api.dart';
import '../data/chat_repository.dart';
import '../archive/archive_provider.dart';
import 'vault_gate_recovery_setup.dart';

/// Stands in front of the chat until this device holds the account's message
/// key.
///
/// On a first launch it mints one, wraps it under a fresh recovery code and
/// shows that code once — the only moment it can be shown, since nothing keeps
/// a copy. On every launch after that it loads the key and gets out of the way.
/// It asks for the code only where the key genuinely is not here, because
/// AbabilX has none to hand over: that is what end-to-end encryption means.
class MessageVaultGate extends ConsumerStatefulWidget {
  const MessageVaultGate({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<MessageVaultGate> createState() => _MessageVaultGateState();
}

class _MessageVaultGateState extends ConsumerState<MessageVaultGate> {
  // Tracked by hand rather than as a bare Future in a FutureBuilder: a builder
  // only ever checks snapshot.hasData, so a thrown or timed-out check would
  // spin forever instead of offering a retry.
  bool _checking = true;
  Object? _error;
  VaultIdentityState _state = VaultIdentityState.unlock;
  String _recoveryCode = '';
  bool _recovering = false;
  bool _resetting = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final vault = ref.read(messageVaultProvider);
      final state = await vault.ensureIdentity().timeout(
        firstLoadNetworkTimeout,
      );
      if (!mounted) return;
      // Nothing keeps a copy of the code, so a missing one here means the chat
      // opens and the user makes a new one from Settings later — better than
      // blocking on a screen with nothing to show.
      final code = state == VaultIdentityState.setup
          ? (vault.takePendingRecoveryCode() ?? '')
          : '';
      setState(() {
        _state = code.isEmpty && state == VaultIdentityState.setup
            ? VaultIdentityState.ready
            : state;
        _recoveryCode = code;
        _checking = false;
      });
      if (_state == VaultIdentityState.ready) await _finish();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _checking = false;
      });
    }
  }

  /// Shared by every route into a working vault. Any DM bubble hydrated from a
  /// previous session is still showing the locked placeholder, so it is
  /// resolved here rather than in each caller.
  ///
  /// [pullHistory] is only true after the recovery code — not after a local
  /// key load, not after minting a new identity. That is the one shot the
  /// newest page of every chat is pulled into this phone.
  Future<void> _finish({bool pullHistory = false}) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      final chat = ref.read(chatProvider.notifier);
      await chat.fetchSidebar(silent: true);
      await chat.redecryptFailedMessages();
      if (pullHistory) {
        await chat.markHistoryRestorePending();
        await ref.read(archiveProvider.notifier).markRecoveryPending();
      }
      // No-ops unless recovery just set the pending bit (or a killed first
      // run left it set). Ordinary unlocks never pull.
      unawaited(chat.startHistoryRestoreIfNeeded());
      if (mounted) widget.onUnlocked();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _startFresh() async {
    if (_resetting) return;
    setState(() => _resetting = true);
    try {
      final userId = await ref
          .read(chatProvider.notifier)
          .ensureCurrentUserId();
      if (!mounted) return;
      final status = await ref.read(chatRepositoryProvider).getE2eeVault();
      if (!mounted) return;
      final remote = status['vault'];
      await ref
          .read(messageVaultProvider)
          .startSession(
            userId: userId,
            api: ref.read(chatRecoveryApiProvider),
            expectedPublicKey: remote is Map
                ? Map<String, dynamic>.from(remote['public_key'] as Map)
                : null,
          );
      if (mounted) await _finish();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return VaultGateError(
        error: _error!,
        onRetry: ref.read(messageVaultProvider).isUnlocked ? _finish : _load,
      );
    }
    if (_state == VaultIdentityState.ready) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_state == VaultIdentityState.setup) {
      return PopScope(
        canPop: false,
        child: VaultGateRecoverySetup(code: _recoveryCode, onSaved: _finish),
      );
    }
    if (!_recovering) {
      return VaultGateRecoveryChoice(
        busy: _resetting,
        onRecover: () => setState(() => _recovering = true),
        onStartFresh: _startFresh,
      );
    }
    return VaultGateRecoveryCode(
      onUnlocked: () => _finish(pullHistory: true),
      onBack: () => setState(() => _recovering = false),
    );
  }
}
