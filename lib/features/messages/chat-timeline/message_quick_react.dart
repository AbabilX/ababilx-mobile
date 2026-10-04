import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-details/group_permissions.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'signal_message_menu_panels.dart';

/// The emoji a double tap leaves: the first of the reaction bar's own six, so
/// the shortcut and the bar never disagree about what "the default" is.
String get quickReactionEmoji => SignalReactionBar.emojis.first;

/// Whether a double tap may react to [msg]. A pending send has no server id
/// to react to, and a member an admin made read-only cannot react at all
/// (server 0157) — the same gate the menu's reaction bar answers to.
bool canQuickReact(WidgetRef ref, ChatMessage msg) {
  if (msg.isDeleted || msg.isPending) return false;
  final conversation = ref
      .read(chatProvider)
      .conversationById(msg.conversationId);
  return conversation == null || GroupPermissions(conversation).canSend;
}

/// Double tap: toggles the default reaction, so a second double tap takes it
/// back. Drawn locally first by the notifier; a refusal restores the old set.
void quickReact(WidgetRef ref, ChatMessage msg) {
  HapticFeedback.lightImpact();
  unawaited(
    ref
        .read(chatProvider.notifier)
        .toggleReaction(msg.id, quickReactionEmoji)
        .catchError((_) {}),
  );
}

/// Tap on a failed bubble: send it again.
void retryFailedMessage(BuildContext context, WidgetRef ref, ChatMessage msg) {
  ref.read(chatProvider.notifier).retrySend(msg);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Resending message…'),
      duration: Duration(seconds: 2),
    ),
  );
}
