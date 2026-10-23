import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/recent_sign_in.dart';
import '../data/chat_recovery_api.dart';
import '../data/chat_repository.dart';
import '../providers/chat_provider.dart';
import 'message_vault.dart';

enum NewChatSetupState {
  idle,
  running,
  failed,

  /// The server wants a recent sign-in and the phone could not do one by
  /// itself (cancelled Google picker, or an email account).
  needsSignIn,
  ready;

  bool get pending => this == running || this == failed || this == needsSignIn;
}

final newChatSetupProvider = NotifierProvider<NewChatSetup, NewChatSetupState>(
  NewChatSetup.new,
);

/// Owned by the app container, so leaving the decision screen does not cancel
/// setup. The vault persists the candidate before the first network write.
class NewChatSetup extends Notifier<NewChatSetupState> {
  Future<void> Function(int)? _operation;
  int _epoch = 0;
  ReauthOutcome? _signInOutcome;

  /// No sign-in this phone can run by itself (email account): the way on is
  /// signing out and in again. Otherwise a retry asks again.
  bool get signOutToContinue => _signInOutcome == ReauthOutcome.notSupported;
  @override
  NewChatSetupState build() => NewChatSetupState.idle;

  void start({
    String? userId,
    Map<String, dynamic>? expectedPublicKey,
    bool fetchIdentity = false,
  }) {
    if (state.pending) return;
    final vault = ref.read(messageVaultProvider);
    final api = ref.read(chatRecoveryApiProvider);
    final repo = ref.read(chatRepositoryProvider);
    vault.beginNewChat();
    _operation = (epoch) async {
      final id =
          userId ?? await ref.read(chatProvider.notifier).ensureCurrentUserId();
      var expected = expectedPublicKey;
      if (fetchIdentity) {
        final status = await repo.getE2eeVault();
        final remote = status['vault'];
        expected = remote is Map
            ? Map<String, dynamic>.from(remote['public_key'] as Map)
            : null;
      }
      if (epoch != _epoch) return;
      await vault.startSession(
        userId: id,
        api: api,
        expectedPublicKey: expected,
        clearHistory: true,
      );
    };
    retry();
  }

  void retry() {
    if (state == NewChatSetupState.running || _operation == null) return;
    state = NewChatSetupState.running;
    unawaited(_run(++_epoch));
  }

  Future<void> _run(int epoch) async {
    try {
      await _operation!(epoch);
      if (epoch == _epoch) state = NewChatSetupState.ready;
    } on RecentSignInRequired catch (error) {
      if (epoch != _epoch) return;
      _signInOutcome = error.outcome;
      // Offline is not a refusal: an ordinary retry is the right offer.
      state = error.outcome == ReauthOutcome.unavailable
          ? NewChatSetupState.failed
          : NewChatSetupState.needsSignIn;
    } catch (_) {
      if (epoch == _epoch) state = NewChatSetupState.failed;
    }
  }

  void reset() {
    _epoch++;
    _operation = null;
    state = NewChatSetupState.idle;
  }
}
