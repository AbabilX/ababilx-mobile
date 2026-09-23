import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/data/models/attachment_url_key.dart';
import '../attachments/storage/storage_providers.dart';
import '../ghost/protocol/ghost_item_rules.dart';
import '../messages/data/models/chat_models.dart';
import 'privacy_media_sheet.dart';
import 'privacy_mode_provider.dart';

/// The Ghost Chat timer as the server stores it: null = no timer, 0 = view
/// once, else seconds.
int? viewSecondsOf(GhostViewTimer timer) => switch (timer) {
  GhostViewTimer.off => null,
  GhostViewTimer.once => 0,
  _ => timer.duration!.inSeconds,
};

/// Stamps the sender's choice on every attachment of one send. The timer
/// only goes on when every attachment is a photo — a PDF with a five-second
/// clock is a PDF nobody can read.
List<ChatAttachmentInput> applyPrivacyRules(
  List<ChatAttachmentInput> attachments,
  GhostItemRules rules,
) {
  final timer = allPhotos(attachments) ? rules.timer : GhostViewTimer.off;
  return [
    for (final a in attachments)
      a.withPolicy(viewSeconds: viewSecondsOf(timer), noSave: !rules.allowSave),
  ];
}

bool allPhotos(List<ChatAttachmentInput> attachments) =>
    attachments.isNotEmpty &&
    attachments.every((a) => looksLikeImage(a.contentType, a.fileName));

/// Drops this phone's copy of every attachment that [next] reports expired.
/// The server blanks the URL on expiry, so the local blob is found under the
/// URL [previous] still carried. The decoded-image cache goes too: a picture
/// still sitting in memory is a copy that outlived its timer.
Future<void> wipeExpiredMedia(
  Ref ref,
  ChatMessage? previous,
  ChatMessage next,
) async {
  if (previous == null) return;
  final keys = <String>[];
  for (final att in next.attachments) {
    if (!att.expired) continue;
    for (final old in previous.attachments) {
      if (old.id == att.id && old.fileUrl.isNotEmpty) {
        keys.add(attachmentUrlKey(old.fileUrl));
      }
    }
  }
  if (keys.isEmpty) return;
  await ref.read(storageManagerProvider).purgeUrlKeys(keys);
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

/// The composer's hook: when this account is in privacy mode and is sending
/// photos or files into a DM, ask for the timer / saving choice first.
///
/// Returns [attachments] unchanged when the sheet does not apply, the stamped
/// copies when it does, and null when the sender backed out.
Future<List<ChatAttachmentInput>?> askPrivacyMediaRules(
  BuildContext context,
  WidgetRef ref,
  ChatConversation? conversation,
  List<ChatAttachmentInput> attachments,
) async {
  if (attachments.isEmpty) return attachments;
  if (conversation == null || !conversation.hasDmPeer) return attachments;
  if (!await ref.read(privacyModeProvider.notifier).resolve()) {
    return attachments;
  }
  if (!context.mounted) return null;
  final rules = await showPrivacyMediaSheet(
    context,
    peerName: conversation.displayTitle(null),
    photosOnly: allPhotos(attachments),
  );
  if (rules == null) return null;
  return applyPrivacyRules(attachments, rules);
}

/// Drops this phone's copy of the timed photos it just sent. The sender only
/// ever sees the card, never the picture, so the bytes the upload adopted are
/// a copy with no reader — and "deleted everywhere" includes the sender.
Future<void> purgeSentTimedMedia(
  WidgetRef ref,
  List<ChatAttachmentInput> sent,
) async {
  final keys = [
    for (final a in sent)
      if (a.viewSeconds != null && a.fileUrl.isNotEmpty)
        attachmentUrlKey(a.fileUrl),
  ];
  if (keys.isEmpty) return;
  await ref.read(storageManagerProvider).purgeUrlKeys(keys);
}
