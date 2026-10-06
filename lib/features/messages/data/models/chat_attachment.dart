import 'package:equatable/equatable.dart';

import '../../../attachments/crypto/attachment_secret.dart';

export 'chat_attachment_input.dart';
export 'chat_presign_result.dart';

/// The attachment rules on bare strings, for code that holds a stored blob
/// (content type + file name) rather than a message attachment.
bool looksLikeImage(String contentType, String fileName) {
  if (contentType.toLowerCase().startsWith('image/')) return true;
  return _imageName.hasMatch(fileName);
}

bool looksLikeVideo(String contentType, String fileName) {
  if (contentType.toLowerCase().startsWith('video/')) return true;
  return _videoName.hasMatch(fileName);
}

final _imageName = RegExp(
  r'\.(jpe?g|png|gif|webp|bmp|heic|heif|avif|svg)$',
  caseSensitive: false,
);
final _videoName = RegExp(
  r'\.(mp4|m4v|mov|webm|mkv|avi|3gp)$',
  caseSensitive: false,
);

class ChatMessageAttachment extends Equatable {
  const ChatMessageAttachment({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.createdAt,
    this.locked = false,
    this.viewSeconds,
    this.noSave = false,
    this.viewedAt,
    this.expiresAt,
    this.expired = false,
    this.encMeta = '',
    this.encNonce = '',
    this.encKeyVersion = 0,
    this.secret,
  });

  final String id;
  final String messageId;
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int sizeBytes;
  final String uploadedBy;
  final String createdAt;
  final bool locked;

  /// Sender-controlled media (privacy mode, server migration 0152).
  /// [viewSeconds]: null = no timer, 0 = view once, else seconds from the
  /// receiver's first open. [noSave]: opens only inside the app. [expired]:
  /// the file is gone everywhere — [fileUrl] is empty and the local copy
  /// must be wiped.
  final int? viewSeconds;
  final bool noSave;
  final String? viewedAt;
  final String? expiresAt;
  final bool expired;

  /// A file its sender encrypted before uploading (server migration 0168):
  /// the object at [fileUrl] is ciphertext, and [encMeta] is its key, real
  /// name and real type sealed under the conversation key at
  /// [encKeyVersion]. Until it is opened, [fileName] and [contentType] are
  /// only the server's `file` / coarse kind.
  final String encMeta;
  final String encNonce;
  final int encKeyVersion;

  /// Set once [encMeta] has been opened on this device — see
  /// `MessageVault.decryptMessage`. Then [fileName], [contentType] and
  /// [sizeBytes] are the real ones. Never written to disk: [toJson] puts the
  /// sealed form back.
  final AttachmentSecret? secret;

  bool get isSealed => encMeta.isNotEmpty;

  /// Encrypted, and this device has not been able to open its key (vault
  /// locked, or a key version this account does not hold). It cannot be
  /// downloaded into anything readable yet.
  bool get needsKey => isSealed && secret == null;

  /// This attachment with its sealed meta opened.
  ChatMessageAttachment opened(AttachmentSealPayload payload) =>
      ChatMessageAttachment(
        id: id,
        messageId: messageId,
        fileName: payload.fileName.isEmpty ? fileName : payload.fileName,
        fileUrl: fileUrl,
        contentType: payload.contentType.isEmpty
            ? contentType
            : payload.contentType,
        sizeBytes: payload.plainSize,
        uploadedBy: uploadedBy,
        createdAt: createdAt,
        locked: locked,
        viewSeconds: viewSeconds,
        noSave: noSave,
        viewedAt: viewedAt,
        expiresAt: expiresAt,
        expired: expired,
        encMeta: encMeta,
        encNonce: encNonce,
        encKeyVersion: encKeyVersion,
        secret: AttachmentSecret(
          key: payload.key,
          plainSize: payload.plainSize,
          cipherSize: sizeBytes,
          wireName: fileName,
          wireType: contentType,
        ),
      );

  bool get timed => viewSeconds != null;

  /// A timer or no saving: never saved, shared, forwarded or listed.
  bool get isProtected => timed || noSave || expired;

  bool get isImage => looksLikeImage(contentType, fileName);

  bool get isPdf {
    final ct = contentType.toLowerCase();
    if (ct == 'application/pdf' || ct == 'application/x-pdf') return true;
    return fileName.toLowerCase().endsWith('.pdf');
  }

  bool get isVideo => looksLikeVideo(contentType, fileName);

  bool get isAudio {
    if (contentType.toLowerCase().startsWith('audio/')) return true;
    // Prefer video when extension is ambiguous (e.g. .webm).
    if (isVideo) return false;
    return RegExp(
      r'\.(m4a|aac|mp3|ogg|opus|wav|webm)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  factory ChatMessageAttachment.fromJson(Map<String, dynamic> json) =>
      ChatMessageAttachment(
        id: json['id'] as String? ?? '',
        messageId: json['message_id'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        uploadedBy: json['uploaded_by'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        locked: json['locked'] as bool? ?? false,
        viewSeconds: (json['view_seconds'] as num?)?.toInt(),
        noSave: json['no_save'] as bool? ?? false,
        viewedAt: json['viewed_at'] as String?,
        expiresAt: json['expires_at'] as String?,
        expired: json['expired'] as bool? ?? false,
        encMeta: json['enc_meta'] as String? ?? '',
        encNonce: json['enc_nonce'] as String? ?? '',
        encKeyVersion: (json['enc_key_version'] as num?)?.toInt() ?? 0,
      );

  /// The row as the server serves it. An opened encrypted attachment goes
  /// back to its sealed form here, so the local message store never holds a
  /// file key or a real file name beside the ciphertext's URL.
  Map<String, dynamic> toJson() => {
    'id': id,
    'message_id': messageId,
    'file_name': secret?.wireName ?? fileName,
    'file_url': fileUrl,
    'content_type': secret?.wireType ?? contentType,
    'size_bytes': secret?.cipherSize ?? sizeBytes,
    'uploaded_by': uploadedBy,
    'created_at': createdAt,
    'locked': locked,
    'view_seconds': ?viewSeconds,
    if (noSave) 'no_save': true,
    'viewed_at': ?viewedAt,
    'expires_at': ?expiresAt,
    if (expired) 'expired': true,
    if (isSealed) 'enc_meta': encMeta,
    if (isSealed) 'enc_nonce': encNonce,
    if (isSealed) 'enc_key_version': encKeyVersion,
  };

  @override
  List<Object?> get props => [id, fileUrl, viewedAt, expired, needsKey];
}
