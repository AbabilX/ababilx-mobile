import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../local-backup/format/backup_errors.dart';
import '../local_share/services/local_ip_service.dart';
import '../messages/message_e2ee/message_vault.dart';
import '../messages/message_e2ee/p256_ecdh.dart';
import '../profile/data/session_repository.dart';
import 'net/transfer_chats_server.dart';
import 'transfer_chats_service.dart';
import 'wire/transfer_chats_payload.dart';
import 'wire/transfer_chats_wire.dart';

/// The new device, from drawing the code to the last imported message.
///
/// Lives as long as its screen: [dispose] stops the server and deletes the
/// received stream, so a code on a closed screen opens nothing.
class TransferReceiveSession {
  TransferReceiveSession({
    required this.service,
    required this.vault,
    required this.sessions,
    required this.userId,
  });

  final TransferChatsService service;
  final MessageVault vault;
  final SessionRepository sessions;
  final String userId;

  /// The code to draw: null while starting, empty when there is no Wi-Fi.
  final payload = ValueNotifier<String?>(null);
  final status = ValueNotifier<TransferStatus>(const TransferStatus());

  /// The account's message key is on this phone now, whatever happens to
  /// the chats after it. Leaving must not offer "start fresh" over it.
  bool keyAdopted = false;

  TransferChatsServer? _server;
  File? _file;
  late final List<int> _secret = newTransferSecret();
  late final P256KeyPair _ephemeral = vault.newLinkEphemeral();
  DateTime _lastBytes = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  Future<void> start() async {
    final ips = await LocalIpService().getLanIps();
    if (ips.isEmpty) {
      payload.value = '';
      return;
    }
    // The old device checks this sign-in is in its own account's list.
    final mine = (await sessions.list()).where((s) => s.current).toList();
    if (mine.isEmpty) throw StateError('No current session');
    final server = TransferChatsServer(
      token: await transferAuthToken(_secret),
      onIdentity: (envelope) async {
        await vault.adoptLinkedIdentity(envelope, _ephemeral);
        keyAdopted = true;
      },
      streamFile: _streamFile,
      onReceived: _import,
      status: () => status.value,
      onBytes: _onBytes,
    );
    final port = await server.start();
    if (_disposed) return server.stop();
    _server = server;
    payload.value = buildTransferChatsPayload(
      TransferChatsCode(
        addresses: [for (final ip in ips) '$ip:$port'],
        secret: _secret,
        linkKey: vault.encodeLinkPublicKey(_ephemeral),
        userId: userId,
        sessionId: mine.first.id,
      ),
    );
  }

  Future<File> _streamFile() async {
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}/transfer-chats',
    );
    await dir.create(recursive: true);
    return _file = File('${dir.path}/incoming.abxbackup');
  }

  /// At most a few times a second: a chunk arrives every few milliseconds.
  void _onBytes(int bytes) {
    final now = DateTime.now();
    if (now.difference(_lastBytes) < const Duration(milliseconds: 200)) return;
    _lastBytes = now;
    _set(status.value.copyWith(step: TransferStep.receiving, bytes: bytes));
  }

  Future<void> _import(File file) async {
    _set(status.value.copyWith(step: TransferStep.importing));
    try {
      final stats = await service.import(
        file,
        userId: userId,
        secret: _secret,
        onProgress: (n) => _set(status.value.copyWith(messages: n)),
      );
      _set(
        status.value.copyWith(
          step: TransferStep.done,
          messages: stats.messages,
          files: stats.files,
        ),
      );
    } catch (error) {
      debugPrint('[TransferChats] import failed: $error');
      _set(
        status.value.copyWith(
          step: TransferStep.failed,
          error: switch (error) {
            BackupWrongAccountError() => 'wrong_account',
            BackupIncompleteError() => 'incomplete',
            // ENOSPC is 28 on Linux, so on Android.
            FileSystemException(:final osError) when osError?.errorCode == 28 =>
              'no_space',
            _ => 'failed',
          },
        ),
      );
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  void _set(TransferStatus next) {
    if (!_disposed) status.value = next;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _server?.stop();
    _server = null;
    final file = _file;
    if (file != null) await file.delete().catchError((_) => file);
    payload.dispose();
    status.dispose();
  }
}
