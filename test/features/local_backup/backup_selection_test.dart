import 'package:ababilx/features/local-backup/data/backup_choices.dart';
import 'package:ababilx/features/local-backup/export/backup_selection.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation conv(
  String type, {
  bool privateChat = false,
  bool self = false,
}) => ChatConversation.fromJson({
  'id': 'c-$type',
  'type': type,
  'name': type,
  'private_chat': privateChat,
  'is_self': self,
});

ChatMessageAttachment att(
  String name,
  String type, {
  bool noSave = false,
  int? viewSeconds,
  bool locked = false,
}) => ChatMessageAttachment(
  id: name,
  messageId: 'm',
  fileName: name,
  fileUrl: 'https://cdn/$name',
  contentType: type,
  sizeBytes: 10,
  uploadedBy: 'u',
  createdAt: '',
  noSave: noSave,
  viewSeconds: viewSeconds,
  locked: locked,
);

ChatMessage msg({bool privateChat = false, String? deletedAt}) => ChatMessage(
  id: 'm1',
  conversationId: 'c',
  userId: 'u',
  body: 'hi',
  createdAt: '2026-09-27T00:00:00Z',
  privateChat: privateChat,
  deletedAt: deletedAt,
);

void main() {
  const defaults = BackupChoices();

  test('defaults: text + photos + voice notes, both chat kinds', () {
    expect(defaults.photos && defaults.voiceNotes, isTrue);
    expect(defaults.videos || defaults.documents, isFalse);
    expect(defaults.directMessages && defaults.groups, isTrue);
  });

  test(
    'media kinds: a voice note is a voice-* audio, other audio a document',
    () {
      expect(
        backupMediaKind(att('a.jpg', 'image/jpeg')),
        BackupMediaKind.photo,
      );
      expect(backupMediaKind(att('a.mp4', 'video/mp4')), BackupMediaKind.video);
      expect(
        backupMediaKind(att('voice-123.m4a', 'audio/mp4')),
        BackupMediaKind.voiceNote,
      );
      expect(
        backupMediaKind(att('song.mp3', 'audio/mpeg')),
        BackupMediaKind.document,
      );
      expect(
        backupMediaKind(att('a.pdf', 'application/pdf')),
        BackupMediaKind.document,
      );
    },
  );

  test('bytes follow the choices', () {
    expect(
      attachmentBytesIncluded(att('a.jpg', 'image/jpeg'), defaults),
      isTrue,
    );
    expect(
      attachmentBytesIncluded(att('a.mp4', 'video/mp4'), defaults),
      isFalse,
    );
    final all = defaults.copyWith(videos: true, documents: true);
    expect(attachmentBytesIncluded(att('a.mp4', 'video/mp4'), all), isTrue);
    expect(
      attachmentBytesIncluded(att('a.pdf', 'application/pdf'), all),
      isTrue,
    );
    final none = defaults.copyWith(photos: false);
    expect(attachmentBytesIncluded(att('a.jpg', 'image/jpeg'), none), isFalse);
  });

  test('protected media is never saved, whatever the choices', () {
    final all = defaults.copyWith(videos: true, documents: true);
    expect(
      attachmentBytesIncluded(att('a.jpg', 'image/jpeg', noSave: true), all),
      isFalse,
    );
    expect(
      attachmentBytesIncluded(att('a.jpg', 'image/jpeg', viewSeconds: 0), all),
      isFalse,
    );
    expect(
      attachmentBytesIncluded(att('a.jpg', 'image/jpeg', locked: true), all),
      isFalse,
    );
  });

  test(
    'chat switches; Note to Self is a DM, feeds and unknown chats are groups',
    () {
      final dmsOnly = defaults.copyWith(groups: false);
      final groupsOnly = defaults.copyWith(directMessages: false);
      expect(conversationIncluded(conv('dm'), dmsOnly), isTrue);
      expect(conversationIncluded(conv('dm', self: true), groupsOnly), isFalse);
      expect(conversationIncluded(conv('group'), dmsOnly), isFalse);
      expect(conversationIncluded(conv('webhook'), groupsOnly), isTrue);
      expect(conversationIncluded(null, groupsOnly), isTrue);
      expect(conversationIncluded(null, dmsOnly), isFalse);
      expect(
        defaults.copyWith(directMessages: false, groups: false).anyChats,
        isFalse,
      );
    },
  );

  test(
    'private chat stays out: the chat while on, and every private message',
    () {
      expect(
        conversationIncluded(conv('dm', privateChat: true), defaults),
        isFalse,
      );
      expect(messageIncluded(msg(privateChat: true)), isFalse);
      expect(messageIncluded(msg()), isTrue);
      expect(messageIncluded(msg(deletedAt: '2026-09-27T00:00:00Z')), isFalse);
    },
  );

  test('choices survive a round trip and fill missing keys with defaults', () {
    final c = defaults.copyWith(videos: true, groups: false);
    final back = BackupChoices.fromJson(c.toJson());
    expect(back.videos, isTrue);
    expect(back.groups, isFalse);
    expect(BackupChoices.fromJson({}).photos, isTrue);
  });
}
