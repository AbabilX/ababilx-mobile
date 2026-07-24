import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';
import 'attach_image.dart';
import 'mention_picker.dart';

class WallComposerActions extends ConsumerWidget {
  const WallComposerActions({
    super.key,
    required this.busy,
    required this.isPremium,
    required this.onMentioned,
    required this.onAttached,
    required this.onSubmit,
  });

  final bool busy;
  final bool isPremium;
  final void Function(String userId, String name) onMentioned;
  final ValueChanged<WallAttachmentInput> onAttached;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          onPressed: () async {
            final m = await showWallMentionPicker(context, ref);
            if (m != null) onMentioned(m.userId, m.displayName);
          },
          icon: const ChatIcon(HugeIcons.strokeRoundedAt),
        ),
        IconButton(
          onPressed: () async {
            final a = await pickWallImageAttachment(
              context,
              ref,
              isPremium: isPremium,
            );
            if (a != null) onAttached(a);
          },
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
