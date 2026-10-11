import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-recipient-picker/chat_recipient_target.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/encryption_pins.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../providers/chat_provider.dart';
import 'forward_targets.dart';

/// Sends the forward, preparing one payload per destination on this device.
///
/// The old shape — a list of conversation and user ids, nothing else — only
/// ever worked for a plaintext message going to a workspace channel. Every
/// other combination is refused by the server, because a DM and a personal
/// group are end-to-end encrypted and it holds no key to seal a copy with.
/// Those refusals used to arrive as an uncaught exception, which is why the
/// picker sat there after Send with nothing said.
///
/// A multi-select forward is the same work per message, in timeline order, so
/// the destination reads them the way the sender wrote them. Destinations are
/// resolved once: a DM created for the first message must not be created again
/// for the second.
///
/// **The picker closes on Send; the work runs behind it.** Sealing a copy per
/// destination and one request per message used to hold the picker open with
/// a spinner. Everything the background half needs — the root overlay for the
/// result, the provider container, the wording — is taken while the caller is
/// still mounted, because neither [context] nor [ref] may be alive when the
/// last request answers.
Future<void> forwardMessages(
  BuildContext context,
  WidgetRef ref,
  List<ChatMessage> messages,
  List<ChatRecipientTarget> targets,
) async {
  if (messages.isEmpty) return;
  // Forwarding an encrypted message re-seals its plaintext for each
  // destination, so a body this device never opened would be forwarded as the
  // vault's own placeholder string.
  if (messages.any(isUnopenedMessage)) {
    if (context.mounted) {
      _toast(context, ref, 'chat_forward_undecryptable', isError: true);
    }
    return;
  }
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final words = (
    failed: tr('chat_forward_failed'),
    offline: tr('chat_forward_offline'),
    one: tr('chat_forwarded_one'),
    many: tr('chat_forwarded_many'),
  );
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final container = ProviderScope.containerOf(context, listen: false);
  Navigator.of(context, rootNavigator: true).pop();
  unawaited(_forwardBehind(container, overlay, messages, targets, words));
}

typedef _ForwardWords = ({
  String failed,
  String offline,
  String one,
  String many,
});

Future<void> _forwardBehind(
  ProviderContainer container,
  OverlayState? overlay,
  List<ChatMessage> messages,
  List<ChatRecipientTarget> targets,
  _ForwardWords words,
) async {
  void fail(String message) => showAppToastIn(overlay, message, isError: true);
  final notifier = container.read(chatProvider.notifier);
  final vault = container.read(messageVaultProvider);
  final ordered = [...messages]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int sent;
  try {
    final conversations = await _resolveConversations(
      container,
      ordered.first.conversationId,
      targets,
    );
    // Every pick dropped out — a conversation the list no longer holds, or all
    // of them the message's own. Returning quietly here left Send doing
    // nothing visible, which is the one outcome this flow must never have.
    if (conversations.isEmpty) return fail(words.failed);
    // The count reported is destinations, not messages, and it is the WORST
    // any one message managed: a batch where the second message reached one
    // fewer chat than the first must not report the first's number.
    var fewest = conversations.length;
    final userId = container.read(chatProvider).currentUserId;
    final pinned = await container
        .read(encryptionPinsProvider)
        .pinnedAmong(userId, conversations.map((c) => c.id));
    for (final message in ordered) {
      final prepared = await buildForwardTargets(
        vault: vault,
        currentUserId: userId,
        text: message.body,
        conversations: conversations,
        attachments: message.attachments,
        pinned: pinned,
      );
      final delivered = await notifier.forwardMessage(
        messageId: message.id,
        targets: prepared,
      );
      if (delivered < fewest) fewest = delivered;
    }
    sent = fewest;
  } catch (error) {
    // The vault raises `StateError` with a sentence written for a person —
    // "This person must set up secure messages…" — and naming the destination
    // that cannot be sealed for is worth far more than a generic failure.
    if (error is StateError) return fail(error.message);
    return fail(isOfflineError(error) ? words.offline : words.failed);
  }
  if (sent == 0) return fail(words.failed);
  showAppToastIn(
    overlay,
    sent == 1 ? words.one : words.many.replaceAll('{n}', '$sent'),
  );
}

/// Turns picked destinations into real conversations, creating a DM for any
/// person who has none. The conversation has to exist before anything can be
/// encrypted for it — key envelopes are stored per conversation.
Future<List<ChatConversation>> _resolveConversations(
  ProviderContainer ref,
  String sourceConversationId,
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
    if (conversation == null || conversation.id == sourceConversationId) {
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
