import 'dart:async';

import 'package:flutter/foundation.dart';

import '../messages/message_e2ee/message_vault.dart';
import '../profile/data/session_repository.dart';
import 'net/transfer_chats_client.dart';
import 'transfer_chats_service.dart';
import 'wire/transfer_chats_payload.dart';
import 'wire/transfer_chats_wire.dart';

enum SendPhase { connecting, sending, waiting, done, failed }

class TransferSendState {
  const TransferSendState({
    this.phase = SendPhase.connecting,
    this.sent = 0,
    this.remote = const TransferStatus(),
    this.error = '',
  });

  final SendPhase phase;

  /// Messages this device has written into the stream.
  final int sent;

  /// What the new device last reported.
  final TransferStatus remote;

  /// `other_account`, `locked`, `unreachable`, `refused`, `lost`, or the
  /// new device's own code.
  final String error;

  TransferSendState copyWith({
    SendPhase? phase,
    int? sent,
    TransferStatus? remote,
    String? error,
  }) => TransferSendState(
    phase: phase ?? this.phase,
    sent: sent ?? this.sent,
    remote: remote ?? this.remote,
    error: error ?? this.error,
  );
}

class _Stop implements Exception {
  const _Stop(this.code);
  final String code;
}

/// The old device, from the scanned code to the new device's "done".
///
/// Sends nothing until it has proved the code came from a sign-in of this
/// same account: the session id in the code must be in this account's own
/// session list, which only the server can vouch for. A code shown by
/// somebody else's phone is refused before the message key leaves.
class TransferSendSession {
  TransferSendSession({
    required this.service,
    required this.vault,
    required this.sessions,
    required this.userId,
    required this.code,
  });

  final TransferChatsService service;
  final MessageVault vault;
  final SessionRepository sessions;
  final String userId;
  final TransferChatsCode code;

  final state = ValueNotifier<TransferSendState>(const TransferSendState());
  bool _cancelled = false;
  bool _disposed = false;

  Future<void> run() async {
    TransferChatsClient? client;
    try {
      if (code.userId != userId) throw const _Stop('other_account');
      final mine = await sessions.list();
      if (!mine.any((s) => s.id == code.sessionId && !s.current)) {
        throw const _Stop('other_account');
      }
      if (!vault.isUnlocked && !await vault.restoreTrustedIdentity()) {
        throw const _Stop('locked');
      }
      final envelope = await vault.sealIdentityForDevice(
        vault.decodeLinkPublicKey(code.linkKey),
      );
      final token = await transferAuthToken(code.secret);
      client = await TransferChatsClient.reach(code.addresses, token);
      await client.sendIdentity(envelope);
      _set(state.value.copyWith(phase: SendPhase.sending));
      final request = await client.openStream();
      try {
        await service.export(
          request,
          userId: userId,
          secret: code.secret,
          onProgress: (n, _) => _set(state.value.copyWith(sent: n)),
          shouldContinue: () => !_cancelled,
        );
        await client.finishStream(request);
      } catch (_) {
        request.abort();
        rethrow;
      }
      _set(state.value.copyWith(phase: SendPhase.waiting));
      await _waitForImport(client);
    } catch (error) {
      debugPrint('[TransferChats] send stopped: $error');
      _set(
        state.value.copyWith(
          phase: SendPhase.failed,
          error: switch (error) {
            _Stop(:final code) => code,
            TransferUnreachable() => 'unreachable',
            TransferRefused() => 'refused',
            _ => 'lost',
          },
        ),
      );
    } finally {
      client?.close();
    }
  }

  /// The stream is on the new device; it now files every message. Asked
  /// every second; five silent answers in a row mean it went away.
  Future<void> _waitForImport(TransferChatsClient client) async {
    var misses = 0;
    while (!_cancelled) {
      try {
        final remote = await client.status().timeout(
          const Duration(seconds: 5),
        );
        misses = 0;
        _set(state.value.copyWith(remote: remote));
        if (remote.step == TransferStep.done) {
          _set(state.value.copyWith(phase: SendPhase.done));
          return;
        }
        if (remote.step == TransferStep.failed) throw _Stop(remote.error);
      } on _Stop {
        rethrow;
      } catch (_) {
        if (++misses >= 5) throw const _Stop('lost');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  void cancel() => _cancelled = true;

  void _set(TransferSendState next) {
    if (!_disposed) state.value = next;
  }

  void dispose() {
    _cancelled = true;
    _disposed = true;
    state.dispose();
  }
}
