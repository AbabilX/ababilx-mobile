import 'package:file_picker/file_picker.dart';

import '../models/file_dto.dart';

const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};
const _videoExts = {'mp4', 'mov', 'mkv', 'avi', 'webm', '3gp'};
const _textExts = {'txt', 'md', 'json', 'csv', 'log'};

LocalFileType _typeForExtension(String? ext) {
  final e = (ext ?? '').toLowerCase();
  if (e == 'apk') return LocalFileType.apk;
  if (e == 'pdf') return LocalFileType.pdf;
  if (_imageExts.contains(e)) return LocalFileType.image;
  if (_videoExts.contains(e)) return LocalFileType.video;
  if (_textExts.contains(e)) return LocalFileType.text;
  return LocalFileType.other;
}

/// Converts a file_picker [PlatformFile] into a LocalSend-protocol [LocalFileDto].
LocalFileDto fileDtoFromPlatformFile(PlatformFile file, {required int index}) {
  final id = '${DateTime.now().millisecondsSinceEpoch}_$index';
  return LocalFileDto(
    id: id,
    fileName: file.name,
    size: file.size,
    fileType: _typeForExtension(file.extension),
    filePath: file.path,
  );
}
