import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/voice_capture_action.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';

class CrmMediaActions extends StatelessWidget {
  const CrmMediaActions({
    super.key,
    required this.busy,
    required this.onMedia,
    required this.onVoice,
  });

  final bool busy;
  final Future<void> Function(PickedMediaFile file) onMedia;
  final Future<void> Function(RecordedVoiceMessage recording) onVoice;

  Future<void> _pick(
    BuildContext context,
    Future<PickedMediaFile?> Function() picker,
  ) async {
    try {
      final file = await picker();
      if (file != null) await onMedia(file);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VoiceCaptureAction(enabled: !busy, onRecorded: onVoice),
        IconButton(
          tooltip: 'Live camera',
          onPressed: busy ? null : () => _pick(context, pickLiveCameraFile),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: Icon(
            Icons.photo_camera_outlined,
            size: 22,
            color: colors.onSurfaceVariant,
          ),
        ),
        IconButton(
          tooltip: 'Files',
          onPressed: busy ? null : () => _pick(context, pickDeviceFile),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: Icon(
            Icons.attach_file_rounded,
            size: 22,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

Future<PickedMediaFile> pickedVoiceRecording(
  RecordedVoiceMessage recording,
) async {
  final bytes = await File(recording.path).readAsBytes();
  return PickedMediaFile(
    bytes: Uint8List.fromList(bytes),
    fileName: recording.fileName,
    contentType: RecordedVoiceMessage.contentType,
  );
}
