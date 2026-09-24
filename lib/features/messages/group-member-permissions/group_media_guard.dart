import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-details/group_permissions.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// A file an admin does not allow in this group (server 0157). Thrown before
/// the presign, so nothing is uploaded that the server would refuse to attach.
class GroupMediaRestrictedException implements Exception {
  const GroupMediaRestrictedException(this.kind);

  /// Null for a voice note, which rides on Send Messages.
  final GroupMediaKind? kind;
}

/// Refuses [contentType]/[fileName] when the viewer may not send that kind in
/// [conversationId]. A no-op outside a group and on a server without 0157.
void validateGroupMedia(
  WidgetRef ref,
  String conversationId,
  String contentType,
  String fileName,
) {
  final conversation = ref.read(chatProvider).conversationById(conversationId);
  if (conversation == null || conversation.type != 'group') return;
  if (GroupPermissions(conversation).canSendAttachment(contentType, fileName)) {
    return;
  }
  throw GroupMediaRestrictedException(groupMediaKindFor(contentType, fileName));
}

/// The composer's toast for a refused kind, English and Bangla — the
/// composer's own messages come in that pair.
({String en, String bn}) groupMediaRestrictedCopy(GroupMediaKind? kind) =>
    switch (kind) {
      GroupMediaKind.photos => (
        en: 'Admins don\'t allow sending photos in this group.',
        bn: 'এই গ্রুপে অ্যাডমিনরা ছবি পাঠানোর অনুমতি দেননি।',
      ),
      GroupMediaKind.videos => (
        en: 'Admins don\'t allow sending videos in this group.',
        bn: 'এই গ্রুপে অ্যাডমিনরা ভিডিও পাঠানোর অনুমতি দেননি।',
      ),
      GroupMediaKind.music => (
        en: 'Admins don\'t allow sending music in this group.',
        bn: 'এই গ্রুপে অ্যাডমিনরা গান পাঠানোর অনুমতি দেননি।',
      ),
      GroupMediaKind.files => (
        en: 'Admins don\'t allow sending files in this group.',
        bn: 'এই গ্রুপে অ্যাডমিনরা ফাইল পাঠানোর অনুমতি দেননি।',
      ),
      null => (
        en: 'Admins restricted you from sending messages here.',
        bn: 'অ্যাডমিনরা আপনাকে এখানে বার্তা পাঠাতে নিষেধ করেছেন।',
      ),
    };
