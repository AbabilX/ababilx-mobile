import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-recipient-picker/chat_recipient_picker_screen.dart';
import '../chat-recipient-picker/chat_recipient_target.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../providers/chat_provider.dart';
import 'forward_targets.dart';

/// Opens the same full-screen recipient picker as Android Gallery shares.
Future<void> showForwardSheet(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatRecipientPickerScreen(
        actionLabel: AppTranslations.translate(context, ref, 'chat_forward'),
        excludedConversationId: message.conversationId,
        onSubmit: (targets, _) => _forward(context, ref, message, targets),
      ),
    ),
  );
}

/// Sends the forward, preparing one payload per destination on this device.
///
/// The old shape — a list of conversation and user ids, nothing else — only
/// ever worked for a plaintext message going to a workspace channel. Every
/// other combination is refused by the server, because a DM and a personal
/// group are end-to-end encrypted and it holds no key to seal a copy with.
/// Those refusals used to arrive as an uncaught exception, which is why the
/// picker sat there after Send with nothing said.
Future<void> _forward(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
  List<ChatRecipientTarget> targets,
) async {
  final notifier = ref.read(chatProvider.notifier);
  final vault = ref.read(messageVaultProvider);

  // Forwarding an encrypted message re-seals its plaintext for each
  // destination, so a body this device never opened would be forwarded as the
  // vault's own placeholder string.
  if (message.isEncrypted && isVaultPlaceholderBody(message.body)) {
    if (context.mounted) {
      _toast(context, ref, 'chat_forward_undecryptable', isError: true);
    }
    return;
  }

  int sent;
  try {
    final conversations = await _resolveConversations(ref, message, targets);
    // Every pick dropped out — a conversation the list no longer holds, or all
    // of them the message's own. Returning quietly here left Send doing
    // nothing visible, which is the one outcome this flow must never have.
    if (conversations.isEmpty) {
      if (context.mounted) {
        _toast(context, ref, 'chat_forward_failed', isError: true);
      }
      return;
    }
    final prepared = await buildForwardTargets(
      vault: vault,
      currentUserId: ref.read(chatProvider).currentUserId,
      text: message.body,
      conversations: conversations,
    );
    sent = await notifier.forwardMessage(
      messageId: message.id,
      targets: prepared,
    );
  } catch (error) {
    if (!context.mounted) return;
    // Same surface as the success case on purpose. This used to be a bottom
    // SnackBar, which put the two outcomes of one action at opposite ends of
    // the screen.
    //
    // The vault raises `StateError` with a sentence written for a person —
    // "This person must set up secure messages…" — and naming the destination
    // that cannot be sealed for is worth far more than a generic failure.
    if (error is StateError) {
      showAppToast(context, error.message, isError: true);
      return;
    }
    _toast(
      context,
      ref,
      isOfflineError(error) ? 'chat_forward_offline' : 'chat_forward_failed',
      isError: true,
    );
    return;
  }

  if (!context.mounted) return;
  if (sent == 0) {
    _toast(context, ref, 'chat_forward_failed', isError: true);
    return;
  }
  // Toast first, then pop: the entry lives in the root overlay, so it survives
  // the picker closing under it — and closing the picker is the only other
  // thing that happens, which on its own does not say the forward worked.
  showAppToast(context, _forwardedLabel(context, ref, sent));
  Navigator.of(context, rootNavigator: true).pop();
}

/// Turns picked destinations into real conversations, creating a DM for any
/// person who has none. The conversation has to exist before anything can be
/// encrypted for it — key envelopes are stored per conversation.
Future<List<ChatConversation>> _resolveConversations(
  WidgetRef ref,
  ChatMessage message,
  List<ChatRecipientTarget> targets,
) async {
  final notifier = ref.read(chatProvider.notifier);
  final resolved = <String, ChatConversation>{};

  for (final target in targets) {
    ChatConversation? conversation;
    if (target.kind == ChatRecipientKind.conversation) {
      conversation = ref.read(chatProvider).conversationById(target.id);
    } else {
      final existing = ref
          .read(chatProvider)
          .dms
          .where((dm) => dm.peerUserId == target.id);
      conversation = existing.isNotEmpty
          ? existing.first
          : await notifier.startDm(target.id);
    }
    if (conversation == null || conversation.id == message.conversationId) {
      continue;
    }
    resolved[conversation.id] = conversation;
  }
  return resolved.values.toList();
}

void _toast(
  BuildContext context,
  WidgetRef ref,
  String key, {
  bool isError = false,
}) => showAppToast(
  context,
  AppTranslations.translate(context, ref, key),
  isError: isError,
);

String _forwardedLabel(BuildContext context, WidgetRef ref, int sent) {
  if (sent == 1) {
    return AppTranslations.translate(context, ref, 'chat_forwarded_one');
  }
  return AppTranslations.translate(
    context,
    ref,
    'chat_forwarded_many',
  ).replaceAll('{n}', '$sent');
}
