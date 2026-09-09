import '../../attachments/data/models/attachment_url_key.dart';

/// The source's index of what it sent — original ids, timestamps, attachment
/// mapping, hashes, and which files it could not find.
///
/// Sealed under the transfer key like every chunk, so the server relays a list
/// of the user's message ids without ever reading one. The destination needs
/// it to place media back on the right message, and to tell "we could not send
/// this file" apart from "this file has not arrived yet".
class HistoryTransferManifest {
  const HistoryTransferManifest({
    required this.createdAtMs,
    required this.deviceId,
    required this.messageChunkCount,
    required this.attachments,
    required this.messageCount,
    required this.conversationCount,
    this.deletionMarkers = const [],
  });

  static const int version = 1;

  final int createdAtMs;
  final String deviceId;

  /// Message chunks always occupy indexes `0 ..< messageChunkCount`; media
  /// follows. Making the split a count rather than a per-chunk label keeps the
  /// destination's reader from having to trust a field on every chunk.
  final int messageChunkCount;
  final List<HistoryTransferFile> attachments;
  final int messageCount;
  final int conversationCount;

  /// This account's deletion markers, exactly as `/api/me/chat-deletions`
  /// serves them, read at the END of the transfer.
  ///
  /// The snapshot is written page by page, so a message can be exported and
  /// then deleted before the upload finishes — its bytes are already inside a
  /// sealed chunk by then. An explicit deletion outranks anything imported, so
  /// the destination applies these before it activates the import. Carrying
  /// the markers rather than a list of revoked ids also covers a whole
  /// conversation cleared mid-transfer, which an id list never would.
  final List<Map<String, dynamic>> deletionMarkers;

  int get missingCount => attachments.where((file) => !file.available).length;

  Map<String, dynamic> toJson() => {
    'v': version,
    'created_at_ms': createdAtMs,
    'device_id': deviceId,
    'message_chunks': messageChunkCount,
    'messages': messageCount,
    'conversations': conversationCount,
    'deletions': deletionMarkers,
    'attachments': attachments.map((file) => file.toJson()).toList(),
  };

  factory HistoryTransferManifest.fromJson(Map<String, dynamic> json) =>
      HistoryTransferManifest(
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        deviceId: json['device_id'] as String? ?? '',
        messageChunkCount: (json['message_chunks'] as num?)?.toInt() ?? 0,
        messageCount: (json['messages'] as num?)?.toInt() ?? 0,
        conversationCount: (json['conversations'] as num?)?.toInt() ?? 0,
        deletionMarkers: (json['deletions'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList(),
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map(
              (raw) =>
                  HistoryTransferFile.fromJson(Map<String, dynamic>.from(raw)),
            )
            .toList(),
      );
}

/// One attachment, present or not.
///
/// `urlKey` is the join: it is what the local attachment store is keyed by on
/// every device, so the destination files these bytes under the same key its
/// own downloads would use and a later download of the same object finds them
/// already there.
class HistoryTransferFile {
  const HistoryTransferFile({
    required this.urlKey,
    required this.remoteUrl,
    required this.messageId,
    required this.conversationId,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256,
    required this.firstChunk,
    required this.chunkCount,
  });

  final String urlKey;
  final String remoteUrl;
  final String messageId;
  final String conversationId;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// Of the PLAINTEXT bytes. The destination checks it after decrypting, which
  /// is the only place the check means anything — the server sees ciphertext
  /// and could not verify this if it wanted to.
  final String sha256;

  /// -1 when the phone does not hold the file. The message still arrives; the
  /// attachment renders as unavailable rather than as a pending download that
  /// will never complete.
  final int firstChunk;
  final int chunkCount;

  bool get available => firstChunk >= 0 && chunkCount > 0;

  Map<String, dynamic> toJson() => {
    'url_key': urlKey,
    'url': remoteUrl,
    'message_id': messageId,
    'conversation_id': conversationId,
    'file_name': fileName,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'sha256': sha256,
    'first_chunk': firstChunk,
    'chunk_count': chunkCount,
  };

  factory HistoryTransferFile.fromJson(Map<String, dynamic> json) =>
      HistoryTransferFile(
        urlKey:
            json['url_key'] as String? ??
            attachmentUrlKey(json['url'] as String? ?? ''),
        remoteUrl: json['url'] as String? ?? '',
        messageId: json['message_id'] as String? ?? '',
        conversationId: json['conversation_id'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
        firstChunk: (json['first_chunk'] as num?)?.toInt() ?? -1,
        chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
      );
}
