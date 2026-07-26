import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../team/data/models/team_models.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../data/models/wall_models.dart';
import 'attach_image.dart';
import 'composer_toolbar.dart';
import 'pending_previews.dart';
import 'suggestion_panel.dart';

class WallComposerForm extends ConsumerWidget {
  const WallComposerForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.triggerIsMention,
    required this.showSuggestions,
    required this.members,
    required this.categories,
    required this.pending,
    required this.busy,
    required this.isPremium,
    required this.onPickMember,
    required this.onPickCategory,
    required this.onRemovePending,
    required this.onInsertAt,
    required this.onInsertHash,
    required this.onAttached,
    required this.onVoiceRecorded,
    required this.onSubmit,
    required this.onFieldTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool? triggerIsMention;
  final bool showSuggestions;
  final List<TeamMember> members;
  final List<WallCategory> categories;
  final List<WallAttachmentInput> pending;
  final bool busy;
  final bool isPremium;
  final ValueChanged<TeamMember> onPickMember;
  final ValueChanged<WallCategory> onPickCategory;
  final ValueChanged<int> onRemovePending;
  final VoidCallback onInsertAt;
  final VoidCallback onInsertHash;
  final ValueChanged<WallAttachmentInput> onAttached;
  final Future<void> Function(RecordedVoiceMessage recording) onVoiceRecorded;
  final VoidCallback onSubmit;
  final VoidCallback onFieldTap;

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final a = await pickWallImageAttachment(context, ref, isPremium: isPremium);
    if (a != null) onAttached(a);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create post',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'Type @ to mention · # for category',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        if (showSuggestions && triggerIsMention != null) ...[
          const SizedBox(height: 8),
          ComposerSuggestionPanel(
            isMention: triggerIsMention!,
            members: members,
            categories: categories,
            onPickMember: onPickMember,
            onPickCategory: onPickCategory,
          ),
        ],
        const SizedBox(height: 12),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 4,
            maxLines: 8,
            onTap: onFieldTap,
            decoration: const InputDecoration(
              hintText: 'Share an update…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (pending.isNotEmpty)
          WallPendingPreviews(
            items: pending,
            onRemove: onRemovePending,
            onAddPhoto: () => _addPhoto(context, ref),
          )
        else
          _EmptyPhotoRow(
            onCamera: () async {
              final a = await pickWallImageAttachment(
                context,
                ref,
                isPremium: isPremium,
                source: ImageSource.camera,
              );
              if (a != null) onAttached(a);
            },
            onGallery: () async {
              final a = await pickWallImageAttachment(
                context,
                ref,
                isPremium: isPremium,
                source: ImageSource.gallery,
              );
              if (a != null) onAttached(a);
            },
          ),
        WallComposerActions(
          busy: busy,
          isPremium: isPremium,
          onInsertAt: onInsertAt,
          onInsertHash: onInsertHash,
          onAttached: onAttached,
          onVoiceRecorded: onVoiceRecorded,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

/// Shown before any attachment — quick Camera / Gallery entry.
class _EmptyPhotoRow extends StatelessWidget {
  const _EmptyPhotoRow({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onCamera,
            icon: Icon(Icons.photo_camera_outlined, color: colors.primary),
            label: const Text('Camera'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: Icon(Icons.photo_library_outlined, color: colors.primary),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );
  }
}
