import 'package:equatable/equatable.dart';

class WallAttachment extends Equatable {
  const WallAttachment({
    required this.id,
    required this.postId,
    this.commentId,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String? commentId;
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int sizeBytes;
  final String uploadedBy;
  final String createdAt;

  bool get isImage {
    if (contentType.startsWith('image/')) return true;
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
    if (isVideo) return false;
    return RegExp(
      r'\.(m4a|aac|mp3|ogg|opus|wav|webm)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  factory WallAttachment.fromJson(Map<String, dynamic> json) => WallAttachment(
    id: json['id'] as String? ?? '',
    postId: json['post_id'] as String? ?? '',
    commentId: json['comment_id'] as String?,
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

class WallAttachmentInput extends Equatable {
  const WallAttachmentInput({
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
  List<Object?> get props => [fileUrl, fileName];
}

class WallPresignResult {
  const WallPresignResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.objectKey,
  });

  final String uploadUrl;
  final String publicUrl;
  final String objectKey;

  factory WallPresignResult.fromJson(Map<String, dynamic> json) =>
      WallPresignResult(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        objectKey: json['object_key'] as String? ?? '',
      );
}
