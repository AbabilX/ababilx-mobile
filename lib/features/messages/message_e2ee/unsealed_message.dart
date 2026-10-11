import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'dm_roster_pins.dart';
import 'sealed_since.dart';

/// Whether [message] is text that reached a sealed chat without being sealed.
///
/// [after] is the conversation's line in epoch milliseconds, from
/// [unsealedAfterProvider]: null = this chat has no line (nothing is marked),
/// 0 = any time.
///
/// Such a row cannot come from the app: the server refuses plain text into a
/// sealed chat, so someone wrote it into the database, or the server wrote it
/// itself (a task comment relayed as a DM). Either way the name on it proves
/// nothing, and the timeline says so under the bubble.
///
/// Not marked, each on purpose: a system line, a call row and a feed post
/// (the server's own words, drawn as such); a row with files and no text (a
/// file sent from the web is a plain object, a known limit); a send still
/// pending on this phone.
bool isUnsealedText(ChatMessage message, int? after) {
  if (after == null || message.isEncrypted) return false;
  if (message.isPending || message.isDeleted || message.userId.isEmpty) {
    return false;
  }
  if (message.isSystem ||
      message.isVoiceCall ||
      message.isGroupCall ||
      message.isWebhook) {
    return false;
  }
  if (tiptapToPlainText(message.body).trim().isEmpty) return false;
  if (after <= 0) return true;
  final sent = DateTime.tryParse(message.createdAt)?.millisecondsSinceEpoch;
  return sent != null && sent > after;
}

/// The line [isUnsealedText] measures a conversation's rows against.
///
/// A DM has never taken plain text, so every plain text row in one is
/// marked: the line is 0. Whether it is a DM is the list's word OR this
/// phone's own memory of it (DmRosterPins), so a row cannot escape by the
/// server calling the chat a group. A group may hold plain history from
/// before its first key, so its line is the oldest sealed message this phone
/// has opened there (SealedSince), and null until it has opened one.
final unsealedAfterProvider = FutureProvider.autoDispose.family<int?, String>((
  ref,
  conversationId,
) async {
  final userId = ref.watch(chatProvider.select((s) => s.currentUserId));
  final listedDm = ref.watch(
    chatProvider.select(
      (s) => s.conversationById(conversationId)?.isDm ?? false,
    ),
  );
  if (userId.isEmpty || conversationId.isEmpty) return null;
  if (listedDm) return 0;
  // The line moves back as older sealed messages open.
  void moved() => ref.invalidateSelf();
  SealedSince.changes.addListener(moved);
  ref.onDispose(() => SealedSince.changes.removeListener(moved));
  if (await const DmRosterPins().roster(userId, conversationId) != null) {
    return 0;
  }
  return const SealedSince().since(userId, conversationId);
});
