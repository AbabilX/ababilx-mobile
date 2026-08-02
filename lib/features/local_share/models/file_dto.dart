import 'package:equatable/equatable.dart';

/// Supported LocalSend file categories.
enum LocalFileType {
  image,
  video,
  pdf,
  text,
  apk,
  other;

  static LocalFileType parse(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'image':
        return LocalFileType.image;
      case 'video':
        return LocalFileType.video;
      case 'pdf':
        return LocalFileType.pdf;
      case 'text':
        return LocalFileType.text;
      case 'apk':
        return LocalFileType.apk;
      default:
        return LocalFileType.other;
    }
  }

  String toJsonString() => name;
}

/// File metadata DTO sent during LocalSend v2 handshake (`/prepare-upload`).
class LocalFileDto extends Equatable {
  final String id;
  final String fileName;
  final int size;
  final LocalFileType fileType;
  final String? hash;
  final String? preview;
  final String? filePath; // Local path on disk (for outgoing transfers)

  const LocalFileDto({
    required this.id,
    required this.fileName,
    required this.size,
    required this.fileType,
    this.hash,
    this.preview,
    this.filePath,
  });

  factory LocalFileDto.fromJson(Map<String, dynamic> json) {
    return LocalFileDto(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? 'file',
      size: json['size'] as int? ?? 0,
      fileType: LocalFileType.parse(json['fileType'] as String? ?? 'other'),
      hash: json['hash'] as String?,
      preview: json['preview'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'size': size,
      'fileType': fileType.toJsonString(),
      if (hash != null) 'hash': hash,
      if (preview != null) 'preview': preview,
    };
  }

  LocalFileDto copyWith({
    String? id,
    String? fileName,
    int? size,
    LocalFileType? fileType,
    String? hash,
    String? preview,
    String? filePath,
  }) {
    return LocalFileDto(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      size: size ?? this.size,
      fileType: fileType ?? this.fileType,
      hash: hash ?? this.hash,
      preview: preview ?? this.preview,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  List<Object?> get props => [id, fileName, size, fileType, hash, preview, filePath];
}
