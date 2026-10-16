import '../../messages/data/models/chat_attachment.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../messages/data/models/chat_message.dart';
import '../data/backup_choices.dart';

/// The rules for what enters a backup, kept pure so a test can pin them.
///
/// Two kinds of "no" live here and they are not the same. The person's own
/// choices (media kinds, DMs, groups) are [BackupChoices]. Everything else is
/// a promise somebody ELSE was made — private chat, a timer, "don't allow
/// saving" — and is refused whatever the choices say. The other person chose
/// that their message would not be kept; a backup is keeping it.
enum BackupMediaKind { photo, voiceNote, video, document }

BackupMediaKind backupMediaKind(ChatMessageAttachment a) {
  if (a.isImage) return BackupMediaKind.photo;
  if (a.isVideo) return BackupMediaKind.video;
  // Every recorder in the apps names its file `voice-…` (server groupperms
  // uses the same test); any other audio is a file somebody shared.
  if (a.isAudio && a.fileName.toLowerCase().startsWith('voice-')) {
    return BackupMediaKind.voiceNote;
  }
  return BackupMediaKind.document;
}

bool choiceAllows(BackupChoices choices, BackupMediaKind kind) =>
    switch (kind) {
      BackupMediaKind.photo => choices.photos,
      BackupMediaKind.voiceNote => choices.voiceNotes,
      BackupMediaKind.video => choices.videos,
      BackupMediaKind.document => choices.documents,
    };

/// A conversation the sidebar no longer lists (a group left, a feed removed)
/// counts as a group: a DM stays listed until it is deleted, and a deleted
/// chat's messages never reach the exporter at all.
bool conversationIncluded(ChatConversation? conversation, BackupChoices c) {
  if (conversation == null) return c.groups;
  // A private chat is in (2026-10-16): under delivery-only the phone holds
  // the only lasting copy of every chat, and leaving private ones out meant
  // they vanished with the phone. Its no-save media still stays out
  // (attachmentBytesIncluded).
  // Note to Self is a DM (`is_self`), and is a DM here.
  return conversation.isDm ? c.directMessages : c.groups;
}

/// Whether this stored row belongs in a backup at all.
bool messageIncluded(ChatMessage m) =>
    m.id.isNotEmpty && !m.isPending && !m.isDeleted && !m.contentPurged;

/// Whether an attachment's BYTES go in. Its row stays with the message either
/// way, so a skipped kind still shows as a file that can be fetched again
/// while the server has it.
bool attachmentBytesIncluded(ChatMessageAttachment a, BackupChoices choices) =>
    !a.isProtected &&
    !a.locked &&
    a.fileUrl.isNotEmpty &&
    choiceAllows(choices, backupMediaKind(a));
