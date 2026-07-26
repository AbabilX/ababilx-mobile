import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

const int maxWorkspaceAttachmentBytes = 200 * 1024 * 1024;

class PickedMediaFile {
  const PickedMediaFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;

  int get sizeBytes => bytes.length;
}

Future<PickedMediaFile?> pickLiveCameraFile() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 88,
    maxWidth: 2400,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  _checkSize(bytes.length);
  return PickedMediaFile(
    bytes: bytes,
    fileName: file.name,
    contentType: file.mimeType ?? contentTypeForFileName(file.name),
  );
}

Future<PickedMediaFile?> pickGalleryImageFile() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 90,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  _checkSize(bytes.length);
  return PickedMediaFile(
    bytes: bytes,
    fileName: file.name,
    contentType: file.mimeType ?? contentTypeForFileName(file.name),
  );
}

Future<PickedMediaFile?> pickDeviceFile() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  _checkSize(file.size);

  Uint8List? bytes = file.bytes;
  final path = file.path;
  if (bytes == null && path != null && path.isNotEmpty) {
    bytes = await File(path).readAsBytes();
  }
  if (bytes == null || bytes.isEmpty) {
    throw const FileSystemException('Could not read the selected file');
  }
  _checkSize(bytes.length);
  return PickedMediaFile(
    bytes: bytes,
    fileName: file.name,
    contentType: contentTypeForFileName(file.name),
  );
}

String contentTypeForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'm4a' || 'aac' => 'audio/mp4',
    'mp3' => 'audio/mpeg',
    'ogg' || 'opus' => 'audio/ogg',
    'wav' => 'audio/wav',
    _ => 'application/octet-stream',
  };
}

void _checkSize(int sizeBytes) {
  if (sizeBytes <= 0) {
    throw const FileSystemException('The selected file is empty');
  }
  if (sizeBytes > maxWorkspaceAttachmentBytes) {
    throw const FileSystemException('Files must be 200 MB or smaller');
  }
}
