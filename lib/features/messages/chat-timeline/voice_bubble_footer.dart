import 'package:flutter/widgets.dart';

import '../../chat-lock/data/chat_lock_index.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';

/// A message that is one voice note and nothing else. Its time and ticks sit
/// on the player's own second line, beside the clock, instead of on a row
/// under the player.
///
/// A locked chat plays from memory through a different widget that has no
/// such line, so it keeps the ordinary footer.
bool isVoiceBubble(ChatMessage message) {
  if (message.isDeleted || message.quote != null) return false;
  if (message.attachments.length != 1) return false;
  final only = message.attachments.single;
  if (!only.isAudio || only.locked || only.timed || only.expired) return false;
  if (ChatLockIndex.cached.containsKey(message.conversationId)) return false;
  return tiptapToPlainText(message.body).trim().isEmpty;
}

/// Hands the bubble's footer down to the voice player inside it, past the
/// body and attachment layers that have no reason to know about it.
class VoiceBubbleFooter extends InheritedWidget {
  const VoiceBubbleFooter({
    super.key,
    required this.footer,
    required super.child,
  });

  /// Null while the bubble hides its footer.
  final Widget? footer;

  static Widget? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceBubbleFooter>()?.footer;

  @override
  bool updateShouldNotify(VoiceBubbleFooter old) => old.footer != footer;
}
