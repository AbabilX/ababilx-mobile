import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'chat_icon.dart';

/// The bookmark that stands in for a picture on the Note to Self conversation.
///
/// That thread is a DM whose peer is the viewer, so the ordinary DM avatar
/// would be the viewer's own photo — wearing their own presence dot in the
/// list, and inviting a tap through to their own profile. One glyph in the
/// accent colour says what the row is instead, the same way Signal does.
class NoteToSelfAvatar extends StatelessWidget {
  const NoteToSelfAvatar({super.key, this.size = 52, this.iconSize});

  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: ChatIcon(
        HugeIcons.strokeRoundedBookmark01,
        size: iconSize ?? size * 0.45,
        color: colors.onPrimaryContainer,
      ),
    );
  }
}
