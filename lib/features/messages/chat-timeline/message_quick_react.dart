import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../khaam/data/khaam_payload.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'message_actions.dart';

/// Whether a double tap may copy [msg]: the menu's own Copy rule. A Khaam is
/// a card, not text; a body this device never opened would copy the vault's
/// placeholder string; and a files-only message has nothing to copy.
bool canQuickCopy(ChatMessage msg) {
  if (msg.isDeleted || isUnopenedMessage(msg)) return false;
  if (KhaamPayload.tryParse(msg.body) != null) return false;
  return tiptapToPlainText(msg.body).trim().isNotEmpty;
}

/// Double tap: the message text straight to the clipboard, no menu.
void quickCopy(BuildContext context, WidgetRef ref, ChatMessage msg) {
  HapticFeedback.lightImpact();
  unawaited(copyMessageText(context, ref, msg));
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
