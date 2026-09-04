import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/media_quality.dart';
import '../../../shared/media/native_media_send.dart';
import '../../../shared/media/picked_media_file.dart';

/// What the camera produced, whichever camera ran.
class ChatCameraCapture {
  const ChatCameraCapture({required this.files, this.caption = ''});

  final List<PickedMediaFile> files;

  /// Typed under the album in the review screen. Empty from the plain picker,
  /// which has nowhere to type.
  final String caption;

  bool get isEmpty => files.isEmpty;
}

/// Opens the camera and gives back what to send.
///
/// On Android this is the native flow opened at its camera door, so a shot
/// arrives in the same review screen — crop, draw, quality, caption — that the
/// composer's gallery button reaches. The quality chosen there is written back
/// as the remembered default, exactly as it is from the composer.
///
/// Everywhere else it is the plain camera picker it always was: one shot, no
/// review, no caption.
Future<ChatCameraCapture?> captureForChat(WidgetRef ref) async {
  if (await NativeMediaSend.isAvailable()) {
    final native = await NativeMediaSend.open(
      start: NativeMediaStart.camera,
      quality: ref.read(mediaQualityProvider),
    );
    if (native == null) return null;
    await ref.read(mediaQualityProvider.notifier).set(native.quality);
    final files = <PickedMediaFile>[];
    for (final file in native.files) {
      final source = File(file.path);
      if (!await source.exists()) continue;
      files.add(
        PickedMediaFile(
          bytes: await source.readAsBytes(),
          fileName: file.fileName,
          contentType: file.contentType,
        ),
      );
    }
    if (files.isEmpty) return null;
    return ChatCameraCapture(files: files, caption: native.caption);
  }

  final picked = await pickLiveCameraFile();
  if (picked == null) return null;
  return ChatCameraCapture(files: [picked]);
}
