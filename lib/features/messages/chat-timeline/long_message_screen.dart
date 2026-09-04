import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';

/// The whole of a message that was too long for its bubble — Signal's
/// `LongMessageFragment`. Plain scaffold on purpose: this is a reading surface,
/// so it gets the page background rather than a bubble fill, full width, and
/// selectable text.
class LongMessageScreen extends StatelessWidget {
  const LongMessageScreen({super.key, required this.body, this.editedAt});

  final String? body;
  final String? editedAt;

  @override
  Widget build(BuildContext context) {
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied')),
              );
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
