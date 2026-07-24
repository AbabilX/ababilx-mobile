import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../messages/chat_icon.dart';
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
    required this.onSubmit,
  });

  final bool busy;
  final bool isPremium;
  final VoidCallback onInsertAt;
  final VoidCallback onInsertHash;
  final ValueChanged<WallAttachmentInput> onAttached;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mention',
          onPressed: onInsertAt,
          icon: const ChatIcon(HugeIcons.strokeRoundedAt),
        ),
        IconButton(
          tooltip: 'Category',
          onPressed: onInsertHash,
          icon: const Text(
            '#',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Camera',
          onPressed: () => _pick(context, ref, source: ImageSource.camera),
          icon: const ChatIcon(HugeIcons.strokeRoundedCamera01),
        ),
        IconButton(
          tooltip: 'Gallery',
          onPressed: () => _pick(context, ref, source: ImageSource.gallery),
          icon: const ChatIcon(HugeIcons.strokeRoundedImage01),
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
