import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/device_gallery.dart';
import '../../../shared/media/media_quality.dart';
import '../../../shared/media/native_media_send.dart';
import '../data/models/chat_models.dart';
import 'composer_upload.dart';

/// Opens the already-selected Recents media in the native review/editor.
/// Nothing is uploaded until the user confirms that screen.
Future<void> reviewAndUploadRecentMedia(
  WidgetRef ref, {
  required String conversationId,
  required List<DeviceMediaItem> items,
  required int maxSelection,
  required String initialCaption,
  required ValueChanged<String> onAccepted,
  required ValueChanged<ChatAttachmentInput> onAdded,
  required ValueChanged<String> onFailed,
  required VoidCallback onReady,
  UploadProgress? onProgress,
}) async {
  if (items.isEmpty || !await NativeMediaSend.isAvailable()) return;

  final result = await NativeMediaSend.open(
    start: NativeMediaStart.review,
    maxSelection: maxSelection,
    quality: ref.read(mediaQualityProvider),
    initialCaption: initialCaption,
    inputs: [
      for (final item in items)
        NativeMediaInput(
          uri: item.uri,
          fileName: item.name,
          contentType: item.mime,
        ),
    ],
  );
  if (result == null) return;

  await ref.read(mediaQualityProvider.notifier).set(result.quality);
  onAccepted(result.caption);
  await uploadAttachments(
    ref,
    conversationId: conversationId,
    sources: result.files.map(nativeFileSource).toList(),
    onAdded: onAdded,
    onFailed: onFailed,
    onProgress: onProgress,
    onReady: onReady,
  );
}
