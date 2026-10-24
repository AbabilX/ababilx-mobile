import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../local-backup/format/backup_errors.dart';
import '../messages/message_e2ee/message_vault.dart';
import '../profile/data/session_repository.dart';
import 'net/transfer_chats_client.dart';
import 'transfer_chats_service.dart';
import 'wire/transfer_chats_payload.dart';
import 'wire/transfer_chats_wire.dart';

class _Fail implements Exception {
  const _Fail(this.code);
  final String code;
}

/// The new phone takes a COMPUTER's chats (`r=pull`): the computer drew the
/// code, this phone scanned it. Same checks as the other way round — the
/// computer must be a sign-in of this account — then the key, the stream
/// and the import, reported back so the computer knows when it is done.
class TransferPullSession {
  TransferPullSession({
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

  final status = ValueNotifier<TransferStatus>(
    const TransferStatus(step: TransferStep.receiving),
  );

  /// The account's message key is on this phone now.
  bool keyAdopted = false;
  bool _disposed = false;
  DateTime _lastBytes = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> run() async {
    TransferChatsClient? client;
    File? file;
    try {
      if (code.userId != userId) throw const _Fail('other_account');
      final mine = await sessions.list();
      final me = mine.where((s) => s.current).firstOrNull;
      if (me == null ||
          !mine.any((s) => s.id == code.sessionId && !s.current)) {
        throw const _Fail('other_account');
      }
      final ephemeral = vault.newLinkEphemeral();
      client = await TransferChatsClient.reach(
        code.addresses,
        await transferAuthToken(code.secret),
      );
      final envelope = await client.hello({
        'link_key': vault.encodeLinkPublicKey(ephemeral),
        'user_id': userId,
        'session_id': me.id,
      });
      await vault.adoptLinkedIdentity(envelope, ephemeral);
      keyAdopted = true;
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}/transfer-chats',
      );
      await dir.create(recursive: true);
      file = File('${dir.path}/pulled.abxbackup');
      await client.pullStream(file, _onBytes);
      await _step(client, status.value.copyWith(step: TransferStep.importing));
      var reported = 0;
      final stats = await service.import(
        file,
        userId: userId,
        secret: code.secret,
        onProgress: (n) {
          _set(status.value.copyWith(messages: n));
          if (n - reported >= 500) {
            reported = n;
            unawaited(client?.report(status.value));
          }
        },
      );
      await _step(
        client,
        status.value.copyWith(
          step: TransferStep.done,
          messages: stats.messages,
          files: stats.files,
        ),
      );
    } catch (error) {
      debugPrint('[TransferChats] pull stopped: $error');
      final failed = status.value.copyWith(
        step: TransferStep.failed,
        error: switch (error) {
          _Fail(:final code) => code,
          TransferUnreachable() => 'unreachable',
          TransferRefused(:final code) when code.isNotEmpty => code,
          TransferRefused() => 'refused',
          BackupWrongAccountError() => 'wrong_account',
          BackupIncompleteError() => 'incomplete',
          _ => 'lost',
        },
      );
      if (client != null) await _step(client, failed);
      _set(failed);
    } finally {
      client?.close();
      await file?.delete().catchError((_) => file!);
    }
  }

  void _onBytes(int bytes) {
    final now = DateTime.now();
    if (now.difference(_lastBytes) < const Duration(milliseconds: 200)) return;
    _lastBytes = now;
    _set(status.value.copyWith(bytes: bytes));
  }

  Future<void> _step(TransferChatsClient client, TransferStatus next) async {
    _set(next);
    await client.report(next);
  }

  void _set(TransferStatus next) {
    if (!_disposed) status.value = next;
  }

  Future<void> dispose() async {
    _disposed = true;
    status.dispose();
  }
}
