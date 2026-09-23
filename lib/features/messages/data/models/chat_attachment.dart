import 'package:equatable/equatable.dart';

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
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'message_id': messageId,
    'file_name': fileName,
    'file_url': fileUrl,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'uploaded_by': uploadedBy,
    'created_at': createdAt,
    'locked': locked,
    'view_seconds': ?viewSeconds,
    if (noSave) 'no_save': true,
    'viewed_at': ?viewedAt,
    'expires_at': ?expiresAt,
    if (expired) 'expired': true,
  };

  @override
  List<Object?> get props => [id, fileUrl, viewedAt, expired];
}

class ChatAttachmentInput extends Equatable {
  const ChatAttachmentInput({
    required this.fileUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.viewSeconds,
    this.noSave = false,
  });

  final String fileUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// The privacy-mode send sheet's choice (see [ChatMessageAttachment]).
  /// Travels with the attachment so the outbox keeps it across a retry; the
  /// API lifts it to the message's `media_policy`.
  final int? viewSeconds;
  final bool noSave;

  bool get restricted => viewSeconds != null || noSave;

  ChatAttachmentInput withPolicy({int? viewSeconds, required bool noSave}) =>
      ChatAttachmentInput(
        fileUrl: fileUrl,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: sizeBytes,
        viewSeconds: viewSeconds,
        noSave: noSave || viewSeconds != null,
      );

  factory ChatAttachmentInput.fromJson(Map<String, dynamic> json) =>
      ChatAttachmentInput(
        fileUrl: json['file_url'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        viewSeconds: (json['view_seconds'] as num?)?.toInt(),
        noSave: json['no_save'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'file_url': fileUrl,
    'file_name': fileName,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'view_seconds': ?viewSeconds,
    if (noSave) 'no_save': true,
  };

  @override
  List<Object?> get props => [fileUrl];
}

class ChatPresignResult extends Equatable {
  const ChatPresignResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.objectKey,
  });

  final String uploadUrl;
  final String publicUrl;
  final String objectKey;

  factory ChatPresignResult.fromJson(Map<String, dynamic> json) =>
      ChatPresignResult(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        objectKey: json['object_key'] as String? ?? '',
      );

  @override
  List<Object?> get props => [uploadUrl, publicUrl];
}
