import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../attachments/data/local/attachment_blob_store.dart';
import '../../../attachments/data/models/attachment_handle.dart';
import '../../../attachments/data/models/attachment_url_key.dart';
import '../../data/local/chat_message_row.dart';
import '../../data/local/chat_message_store.dart';
import '../../data/models/chat_models.dart';
import 'live_wire.dart';

typedef LiveSend =
    Future<void> Function(Map<String, dynamic> header, [List<int>? body]);

/// What the phone says on a live history link — protocol section 3. The
/// browser asks; this answers from the phone's own store and files. Nothing
/// is kept between requests: the browser's store is what says what it holds.
class LiveAnswers {
  LiveAnswers({
    required this.messages,
    required this.blobs,
    required this.send,
    required this.windowStartMs,
    required this.open,
  });

  final ChatMessageStore messages;
  final AttachmentBlobStore blobs;
  final LiveSend send;
  final int windowStartMs;

  /// Opens a sealed body the way this phone reads it (its own key, then the
  /// text restored from a local backup, then the server). After "start
  /// fresh" the server holds no key for this account, so the linked browser
  /// can read only what the phone opens for it (user's call, 2026-10-18).
  final Future<String?> Function(ChatMessage message) open;
  final _cancelled = <int>{};

  static const maxPage = 100;
  static const fileSlice = 256 * 1024;

  /// The phone's chat list and deletion markers, sent first on every
  /// connection.
  Future<void> hello(String device, List<ChatConversation> conversations) {
    final convs = [
      for (final c in conversations)
        {
          // The decrypted preview is plaintext of a sealed message.
          'c': c.toJson()..['last_message_body'] = '',
          'newest_ms':
              DateTime.tryParse(
                c.lastMessageAt ?? '',
              )?.millisecondsSinceEpoch ??
              0,
        },
    ];
    return send({
      't': 'hello',
      'v': 1,
      'as_of_ms': DateTime.now().millisecondsSinceEpoch,
      'window_start_ms': windowStartMs,
      'device': device,
      'convs': convs,
      'deletions': messages.deletions.records,
    });
  }

  Future<void> handle(LiveFrame frame) async {
    final req = (frame.header['req'] as num?)?.toInt() ?? 0;
    switch (frame.type) {
      case 'ping':
        return send({'t': 'pong'});
      case 'get':
        return _page(req, frame.header);
      case 'file':
        return _file(req, frame.header['url'] as String? ?? '');
      case 'cancel':
        _cancelled.add(req);
    }
  }

  Future<void> _page(int req, Map<String, dynamic> h) async {
    final conv = h['conv'] as String? ?? '';
    final limit = ((h['limit'] as num?)?.toInt() ?? 20).clamp(1, maxPage);
    final beforeMs = (h['before_ms'] as num?)?.toInt();
    final beforeId = h['before_id'] as String?;
    // One more than asked: whether anything older exists without a 2nd read.
    final rows = await messages.page(
      conv,
      limit: limit + 1,
      beforeMs: beforeMs,
      beforeId: beforeMs == null ? null : beforeId,
    );
    final inWindow = rows
        .where((m) => !m.isPending && m.id.isNotEmpty)
        .where((m) => messageTimeMs(m) >= windowStartMs)
        .toList()
        .reversed
        .toList();
    final page = inWindow.take(limit).toList();
    var more = inWindow.length > limit;
    if (!more &&
        rows.isNotEmpty &&
        messageTimeMs(rows.first) >= windowStartMs) {
      // `page` drops deleted rows after reading, so a short page is not
      // proof of the end: look once past its oldest row.
      final oldest = rows.first;
      final older = await messages.page(
        conv,
        limit: 1,
        beforeMs: messageTimeMs(oldest),
        beforeId: localMessageRowId(oldest),
      );
      more = older.any((m) => messageTimeMs(m) >= windowStartMs);
    }
    await send({
      't': 'page',
      'req': req,
      'conv': conv,
      'count': page.length,
      'more': more,
    }, gzipLines([for (final m in page) await _row(m)]));
  }

  /// The stored row; a sealed body goes as the text this phone reads. The
  /// channel is end to end between the user's own two devices.
  Future<Map<String, dynamic>> _row(ChatMessage m) async {
    final json = m.toJson()
      ..remove('send_status')
      ..removeWhere((key, _) => key.startsWith('pending_'));
    if (!m.isEncrypted) return json;
    final text = await open(m).catchError((_) => null);
    if (text == null) return json;
    return json
      ..['body'] = text
      ..['opened_on_phone'] = true
      ..remove('encrypted_body')
      ..remove('encryption_nonce')
      ..remove('encryption_version')
      ..remove('encryption_key_version');
  }

  Future<void> _file(int req, String url) async {
    final key = attachmentUrlKey(url);
    final blob = key.isEmpty ? null : await blobs.read(key);
    final path = blob?.localPath ?? '';
    final ready =
        blob != null &&
        blob.transferState == AttachmentTransferState.ready.index &&
        path.isNotEmpty &&
        await File(path).exists();
    if (!ready) return send({'t': 'file_head', 'req': req, 'missing': true});
    final file = File(path);
    final size = await file.length();
    final hash = (blob.contentHash ?? '').isNotEmpty
        ? blob.contentHash!
        : (await sha256.bind(file.openRead()).first).toString();
    await send({
      't': 'file_head',
      'req': req,
      'size': size,
      'sha256': hash,
      'name': blob.fileName.isEmpty ? 'file' : blob.fileName,
      'content_type': blob.contentType.isEmpty
          ? 'application/octet-stream'
          : blob.contentType,
    });
    final reader = await file.open();
    try {
      var offset = 0;
      while (offset < size) {
        if (_cancelled.remove(req)) return;
        final bytes = await reader.read(fileSlice);
        if (bytes.isEmpty) break;
        await send({'t': 'file_data', 'req': req, 'offset': offset}, bytes);
        offset += bytes.length;
      }
    } finally {
      await reader.close();
    }
    await send({'t': 'file_end', 'req': req});
  }
}
