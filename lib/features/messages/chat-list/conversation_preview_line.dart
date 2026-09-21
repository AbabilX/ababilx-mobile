import 'package:flutter/material.dart';

import '../chat_list_filters.dart';
import '../chat_list_preview_highlights.dart';
import 'preview_file_badge.dart';

/// Two-line message preview + file badges with rich URLs and mention badges.
class ConversationPreviewLine extends StatelessWidget {
  const ConversationPreviewLine({
    super.key,
    required this.preview,
    required this.style,
    required this.youStyle,
    this.currentUserId,
  });

  final ChatListPreview preview;
  final TextStyle style;
  final TextStyle youStyle;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final empty = !preview.hasText && !preview.hasFiles;

    // Attachment only: one line. The empty text line above a badge row left a
    // blank gap between the name and the badge.
    if (!preview.hasText && preview.hasFiles) {
      return Text.rich(
        TextSpan(
          children: [
            if (preview.fromMe) TextSpan(text: 'You: ', style: youStyle),
            ...attachmentOnlySpans(
              files: preview.files,
              style: style,
              colors: colors,
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: _buildSpans(
              text: preview.text,
              style: style,
              youStyle: youStyle,
              colors: colors,
              fromMe: preview.fromMe && (preview.hasText || preview.hasFiles),
              empty: empty,
            ),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (preview.hasFiles) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < preview.files.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  PreviewFileBadge(file: preview.files[i], colors: colors),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _buildSpans({
    required String text,
    required TextStyle style,
    required TextStyle youStyle,
    required ColorScheme colors,
    required bool fromMe,
    required bool empty,
  }) {
    final spans = <InlineSpan>[];

    if (fromMe) {
      spans.add(TextSpan(text: 'You: ', style: youStyle));
    }

    if (empty) {
      spans.add(TextSpan(text: 'No messages yet', style: style));
      return spans;
    }

    // Prefer TipTap mention labels so "@John Doe" paints as one chip; a
    // character-class regex used to stop at the first space.
    int lastIndex = 0;
    for (final hit in findPreviewHighlights(
      text,
      mentionLabels: preview.mentionLabels,
    )) {
      if (hit.start > lastIndex) {
        spans.add(
          TextSpan(text: text.substring(lastIndex, hit.start), style: style),
        );
      }

      final token = text.substring(hit.start, hit.end);
      if (hit.isUrl) {
        spans.add(
          TextSpan(
            text: token,
            style: style.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else {
        final isMeMention =
            currentUserId != null &&
            token.toLowerCase().contains(currentUserId!.toLowerCase());

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isMeMention
                    ? Colors.amber.withValues(alpha: 0.25)
                    : colors.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                token,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMeMention ? Colors.amber.shade300 : colors.primary,
                ),
              ),
            ),
          ),
        );
      }

      lastIndex = hit.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    return spans;
  }
}
