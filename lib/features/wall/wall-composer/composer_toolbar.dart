import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/voice_capture_action.dart';
import '../../messages/chat_icon.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../data/models/wall_models.dart';
import 'attach_image.dart';

class WallComposerActions extends ConsumerWidget {
  const WallComposerActions({
    super.key,
    required this.busy,
    required this.isPremium,
    required this.onInsertAt,
    required this.onInsertHash,
    required this.onAttached,
    required this.onVoiceRecorded,
    required this.onSubmit,
  });

  final bool busy;
  final bool isPremium;
  final VoidCallback onInsertAt;
  final VoidCallback onInsertHash;
  final ValueChanged<WallAttachmentInput> onAttached;
  final Future<void> Function(RecordedVoiceMessage recording) onVoiceRecorded;
  final VoidCallback onSubmit;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    ImageSource? source,
  }) async {
    final a = await pickWallImageAttachment(
      context,
      ref,
      isPremium: isPremium,
      source: source,
    );
    if (a != null) onAttached(a);
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    final a = await pickWallFileAttachment(context, ref, isPremium: isPremium);
    if (a != null) onAttached(a);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        VoiceCaptureAction(
          enabled: !busy && isPremium,
          onRecorded: onVoiceRecorded,
        ),
        IconButton(
          tooltip: 'Camera',
          onPressed: busy
              ? null
              : () => _pick(context, ref, source: ImageSource.camera),
          icon: const ChatIcon(HugeIcons.strokeRoundedCamera01),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
        IconButton(
          tooltip: 'Files',
          onPressed: busy ? null : () => _pickFile(context, ref),
          icon: const ChatIcon(HugeIcons.strokeRoundedAttachment),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
        IconButton(
          tooltip: 'Mention',
          onPressed: busy ? null : onInsertAt,
          icon: const ChatIcon(HugeIcons.strokeRoundedAt),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
        IconButton(
          tooltip: 'Category',
          onPressed: busy ? null : onInsertHash,
          icon: const Text(
            '#',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
        IconButton(
          tooltip: 'Gallery',
          onPressed: busy
              ? null
              : () => _pick(context, ref, source: ImageSource.gallery),
          icon: const ChatIcon(HugeIcons.strokeRoundedImage01),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
        const Spacer(),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
    );
  }
}
