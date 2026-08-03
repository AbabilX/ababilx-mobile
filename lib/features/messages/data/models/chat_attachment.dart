import 'package:equatable/equatable.dart';

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

  bool get isImage {
    if (contentType.toLowerCase().startsWith('image/')) return true;
    return RegExp(
      r'\.(jpe?g|png|gif|webp|bmp|heic|heif|avif|svg)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  bool get isPdf {
    final ct = contentType.toLowerCase();
    if (ct == 'application/pdf' || ct == 'application/x-pdf') return true;
    return fileName.toLowerCase().endsWith('.pdf');
  }

  bool get isVideo {
    if (contentType.toLowerCase().startsWith('video/')) return true;
    return RegExp(
      r'\.(mp4|m4v|mov|webm|mkv|avi|3gp)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

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
  };

  @override
  List<Object?> get props => [id, fileUrl];
}

class ChatAttachmentInput extends Equatable {
  const ChatAttachmentInput({
    required this.fileUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String fileUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
    'file_url': fileUrl,
    'file_name': fileName,
    'content_type': contentType,
    'size_bytes': sizeBytes,
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
