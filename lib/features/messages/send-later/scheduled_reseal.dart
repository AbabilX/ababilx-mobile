import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/dm_key_rotation.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../message_e2ee/message_vault.dart';
import '../providers/chat_provider.dart';
import 'scheduled_api.dart';
import 'scheduled_message.dart';

final scheduledResealProvider = Provider((ref) => ScheduledReseal(ref));

/// Seals again what the server could not send because the conversation key
/// moved after it was stored (somebody joined, left, or started fresh).
///
/// Only this account's devices can: the server holds ciphertext. The message
/// is opened with the key version it names, sealed under the current one —
/// its files' keys with it — and put back; the server then sends it at its
/// time, or at once when that has passed.
class ScheduledReseal {
  ScheduledReseal(this._ref);

  final Ref _ref;
  final _busy = <String>{};

  /// Every scheduled message of this account's that is waiting on a re-seal.
  /// Best effort: offline or locked, the rows wait for the next run.
  Future<void> runAll() async {
    try {
      final rows = await listAllScheduled(_ref.read(apiClientProvider));
      await run(rows);
    } catch (_) {}
  }

  /// Returns how many of [rows] were sealed again.
  Future<int> run(List<ScheduledMessage> rows) async {
    var done = 0;
    for (final row in rows.where((r) => r.needsReseal)) {
      if (!_busy.add(row.id)) continue;
      try {
        if (await _reseal(row)) done++;
      } catch (_) {
        // Left as it is; the next run tries again.
      } finally {
        _busy.remove(row.id);
      }
    }
    return done;
  }

  Future<bool> _reseal(ScheduledMessage row) async {
    final vault = _ref.read(messageVaultProvider);
    if (!vault.isUnlocked) return false;
    final userId = await _ref.read(chatProvider.notifier).ensureCurrentUserId();
    final opened = await vault.decryptMessage(
      row.asSealedMessage(userId),
      userId,
    );
    // Sealing a placeholder would send the placeholder.
    if (isUnopenedMessage(opened) || isVaultFailureBody(opened.body)) {
      return false;
    }
    if (opened.attachments.any((a) => a.needsKey)) return false;
    final policy = row.request['media_policy'];
    final noSave = policy is Map && policy['allow_save'] == false;
    final files = [
      for (final a in opened.attachments)
        ChatAttachmentInput(
          fileUrl: a.fileUrl,
          fileName: a.fileName,
          contentType: a.contentType,
          sizeBytes: a.sizeBytes,
          noSave: noSave,
          secret: a.secret,
        ),
    ];
    final client = _ref.read(apiClientProvider);
    await sendEncryptedChat(
      vault: vault,
      conversationId: row.conversationId,
      text: opened.body,
      currentUserId: userId,
      attachments: files,
      send: (sealed) => patchScheduled(
        client,
        row.id,
        request: {
          ...row.request,
          'body': '',
          'encrypted_body': sealed.encryptedBody,
          'encryption_nonce': sealed.nonce,
          'encryption_version': 1,
          'encryption_key_version': sealed.keyVersion,
          if (files.isNotEmpty)
            'attachments': [
              for (final a in files)
                a.withSeal(sealed.attachmentSeals[a.fileUrl]).toWire(),
            ],
        },
      ),
    );
    return true;
  }
}
