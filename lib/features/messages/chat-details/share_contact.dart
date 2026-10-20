import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-people/user_qr_payload.dart';
import '../chat-recipient-picker/chat_recipient_picker_screen.dart';
import '../chat-recipient-picker/chat_recipient_target.dart';
import '../data/models/chat_conversation.dart';
import '../providers/chat_provider.dart';

/// The deep link that opens this DM's person, carrying what they let
/// strangers find them by: `/u/<username>`, else `/u/<email>`, else
/// `/u/<+phone>`. It opens them in the app (the sheet a scanned QR code opens)
/// and, without the app, the web page offering it. Empty when every switch is
/// off or privacy mode is on — the server sends nothing to share then.
String sharedContactLink(ChatConversation conversation) {
  if (!conversation.hasDmPeer) return '';
  for (final value in [
    conversation.peerShareHandle,
    conversation.peerShareEmail,
    conversation.peerSharePhone,
  ]) {
    if (value.trim().isNotEmpty) return buildContactLink(value);
  }
  return '';
}

/// What a chat message carrying the person says: their name over the link.
String sharedContactBody(String name, String link) {
  final title = name.trim();
  if (link.isEmpty) return '';
  return title.isEmpty ? link : '$title\n$link';
}

/// "Send in a chat": pick chats, send each the name and the link.
Future<void> sendContactToChats(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final body = sharedContactBody(
    conversation.peerUserName ?? '',
    sharedContactLink(conversation),
  );
  if (body.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatRecipientPickerScreen(
        title: AppTranslations.translate(context, ref, 'chat_share_contact'),
        actionLabel: AppTranslations.translate(context, ref, 'chat_send'),
        excludedConversationId: conversation.id,
        onSubmit: (targets, _) => _send(context, ref, body, targets),
      ),
    ),
  );
}

/// Same shape as a forward: the picker closes on Send and the work runs
/// behind it, reported on the root overlay taken while still mounted.
Future<void> _send(
  BuildContext context,
  WidgetRef ref,
  String body,
  List<ChatRecipientTarget> targets,
) async {
  if (targets.isEmpty) return;
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final words = (
    failed: tr('chat_share_failed'),
    one: tr('chat_shared_one'),
    many: tr('chat_shared_many'),
  );
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final container = ProviderScope.containerOf(context, listen: false);
  Navigator.of(context, rootNavigator: true).pop();
  unawaited(() async {
    final chat = container.read(chatProvider.notifier);
    var sent = 0;
    for (final target in targets) {
      try {
        final id = await _conversationId(container, target);
        final message = await chat.sendMessage(conversationId: id, body: body);
        if (message != null) sent++;
      } catch (_) {
        // One refused destination must not stop the others.
      }
    }
    if (sent == 0) {
      showAppToastIn(overlay, words.failed, isError: true);
    } else {
      showAppToastIn(
        overlay,
        sent == 1 ? words.one : words.many.replaceAll('{n}', '$sent'),
      );
    }
  }());
}

/// A picked chat is used as is; a picked person is their existing DM, or a
/// new one.
Future<String> _conversationId(
  ProviderContainer container,
  ChatRecipientTarget target,
) async {
  if (target.kind == ChatRecipientKind.conversation) return target.id;
  final dms = container.read(chatProvider).dms;
  for (final dm in dms) {
    if (dm.peerUserId == target.id) return dm.id;
  }
  return (await container.read(chatProvider.notifier).startDm(target.id)).id;
}
