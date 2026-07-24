import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'composer_toolbar.dart';
import 'suggestion_panel.dart';
import '../../team/data/models/team_models.dart';

class WallComposerForm extends StatelessWidget {
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
  final VoidCallback onSubmit;
  final VoidCallback onFieldTap;

  @override
  Widget build(BuildContext context) {
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
        TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 4,
          maxLines: 8,
          onTap: onFieldTap,
          decoration: const InputDecoration(
            hintText: 'Share an update…',
            border: OutlineInputBorder(),
          ),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < pending.length; i++)
                Chip(
                  label: Text(pending[i].fileName),
                  onDeleted: () => onRemovePending(i),
                ),
            ],
          ),
        ],
        WallComposerActions(
          busy: busy,
          isPremium: isPremium,
          onInsertAt: onInsertAt,
          onInsertHash: onInsertHash,
          onAttached: onAttached,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}
