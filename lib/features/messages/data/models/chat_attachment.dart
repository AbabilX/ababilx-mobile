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
  });

  final String id;
  final String messageId;
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int sizeBytes;
  final String uploadedBy;
  final String createdAt;

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
      );

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
