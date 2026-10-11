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
import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';

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
///
/// A second failure says why: a bubble that goes back to "Tap to retry" with
/// no word reads as a tap that did nothing.
Future<void> retryFailedMessage(
  BuildContext context,
  WidgetRef ref,
  ChatMessage msg,
) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final words = (
    locked: tr('chat_retry_locked'),
    offline: tr('chat_retry_offline'),
    failed: tr('chat_retry_failed'),
  );
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  HapticFeedback.selectionClick();
  showAppToast(
    context,
    tr('chat_resending'),
    duration: const Duration(seconds: 2),
  );
  final error = await ref.read(chatProvider.notifier).retrySend(msg);
  if (error == null) return;
  final text = isLockedFailedMessage(msg)
      ? words.locked
      : isOfflineError(error)
      ? words.offline
      : '${words.failed} ${serverErrorMessage(error) ?? serverErrorCode(error) ?? ''}'
            .trim();
  showAppToastIn(overlay, text, isError: true);
}
