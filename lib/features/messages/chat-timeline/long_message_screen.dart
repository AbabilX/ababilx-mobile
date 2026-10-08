import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat-pins/pinned_messages_chrome.dart';
import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';
import 'user_profile_sheet.dart';
import '../../../shared/widgets/app_toast.dart';

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
    final top = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                // Clears the floating header: top inset + 8 + 44 button + 8.
                padding: EdgeInsets.fromLTRB(16, top + 68, 16, 32),
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TiptapViewer(
                        content: body,
                        markdown: true,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                        ),
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
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PinnedMessagesTopBar(
              title: 'Message',
              bottomPadding: 8,
              trailing: PinnedMessagesCircleButton(
                icon: HugeIcons.strokeRoundedCopy01,
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: tiptapToPlainText(body)),
                  );
                  if (!context.mounted) return;
                  showAppToast(context, 'Message copied');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
