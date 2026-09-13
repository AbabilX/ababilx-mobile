import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';
import 'user_profile_sheet.dart';

/// The whole of a message that was too long for its bubble — Signal's
/// `LongMessageFragment`. Plain scaffold on purpose: this is a reading surface,
/// so it gets the page background rather than a bubble fill, full width, and
/// selectable text.
class LongMessageScreen extends ConsumerWidget {
  const LongMessageScreen({super.key, required this.body, this.editedAt});

  final String? body;
  final String? editedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: tiptapToPlainText(body)),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Message copied')));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TiptapViewer(
                  content: body,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  onMentionTap: (userId, label) => showUserProfileSheet(
                    context: context,
                    ref: ref,
                    userId: userId,
                    userName: label,
                  ),
                ),
                if (editedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Edited',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
