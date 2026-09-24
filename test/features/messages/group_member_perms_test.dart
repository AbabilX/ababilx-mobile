import 'package:ababilx/features/messages/chat-details/group_permissions.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/group-member-permissions/group_member_tags_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _group({
  String role = 'member',
  GroupMemberPerms? mine,
  String editInfoRole = 'member',
  String addMembersRole = 'member',
}) => ChatConversation(
  id: 'g',
  teamId: '',
  scope: 'personal',
  type: 'group',
  createdAt: '',
  myRole: role,
  myPermissions: mine,
  editInfoRole: editInfoRole,
  addMembersRole: addMembersRole,
);

void main() {
  group('GroupMemberPerms wire shape', () {
    test('matches the server keys and round-trips', () {
      const perms = GroupMemberPerms(sendMessages: true, sendPhotos: true);
      final json = perms.toJson();
      expect(
        json.keys,
        containsAll(<String>[
          'send_messages',
          'send_photos',
          'send_videos',
          'send_files',
          'send_music',
          'add_users',
          'pin_messages',
          'change_info',
          'start_calls',
          'forward',
          'edit_own_tag',
        ]),
      );
      expect(GroupMemberPerms.fromJson(json), perms);
    });

    test('a missing key is never a granted permission', () {
      final perms = GroupMemberPerms.fromJson({'send_messages': true});
      expect(perms.sendMessages, isTrue);
      expect(perms.forward, isFalse);
      expect(GroupMemberPerms.maybeFromJson(null), isNull);
    });

    test('no Send Messages means no media of any kind', () {
      const perms = GroupMemberPerms(sendPhotos: true);
      expect(perms.allowsMedia(GroupMediaKind.photos), isFalse);
      expect(perms.media(GroupMediaKind.photos), isTrue);
    });

    test('conversation JSON carries both sets through disk', () {
      final conv = ChatConversation.fromJson({
        'id': 'g',
        'type': 'group',
        'my_permissions': GroupMemberPerms.all.toJson(),
        'default_permissions': const GroupMemberPerms().toJson(),
      });
      final back = ChatConversation.fromJson(conv.toJson());
      expect(back.myPermissions, GroupMemberPerms.all);
      expect(back.defaultPermissions, const GroupMemberPerms());
    });
  });

  group('attachment kinds follow the server', () {
    test('voice notes are not media', () {
      expect(groupMediaKindFor('audio/mp4', 'voice-message-3s.m4a'), isNull);
      expect(groupMediaKindFor('audio/webm', 'voice-1727.webm'), isNull);
      expect(groupMediaKindFor('audio/mpeg', 'song.mp3'), GroupMediaKind.music);
      expect(groupMediaKindFor('image/gif', 'a.gif'), GroupMediaKind.photos);
      expect(groupMediaKindFor('video/mp4', 'a.mp4'), GroupMediaKind.videos);
      expect(
        groupMediaKindFor('application/pdf', 'a.pdf'),
        GroupMediaKind.files,
      );
    });
  });

  group('GroupPermissions', () {
    test('a read-only member can do nothing that sends', () {
      final p = GroupPermissions(
        _group(mine: GroupMemberPerms.all.copyWith(sendMessages: false)),
      );
      expect(p.canSend, isFalse);
      expect(p.canSendMedia(GroupMediaKind.photos), isFalse);
      expect(p.canSendAttachment('audio/mp4', 'voice-message-1s.m4a'), isFalse);
    });

    test('media kinds are checked one by one', () {
      final p = GroupPermissions(
        _group(mine: GroupMemberPerms.all.copyWith(sendVideos: false)),
      );
      expect(p.canSendAttachment('image/jpeg', 'a.jpg'), isTrue);
      expect(p.canSendAttachment('video/mp4', 'a.mp4'), isFalse);
      expect(p.canSendAttachment('audio/mp4', 'voice-message-1s.m4a'), isTrue);
    });

    test('an admin holds everything whatever the set says', () {
      final p = GroupPermissions(
        _group(role: 'admin', mine: const GroupMemberPerms()),
      );
      expect(p.canSend, isTrue);
      expect(p.canForward, isTrue);
      expect(p.canPinForEveryone, isTrue);
      expect(p.canSetTag(self: false), isTrue);
    });

    test('forward, calls, pins and own tag read the set', () {
      final p = GroupPermissions(
        _group(
          mine: GroupMemberPerms.all.copyWith(
            forward: false,
            startCalls: false,
            pinMessages: false,
          ),
        ),
      );
      expect(p.canForward, isFalse);
      expect(p.canStartCall, isFalse);
      expect(p.canPinForEveryone, isFalse);
      expect(p.canSetTag(self: true), isTrue);
      expect(p.canSetTag(self: false), isFalse);
    });

    test('an older server with no set falls back to the two switches', () {
      final p = GroupPermissions(
        _group(editInfoRole: 'admin', addMembersRole: 'member'),
      );
      expect(p.canEditInfo, isFalse);
      expect(p.canAddMembers, isTrue);
      expect(p.canSend, isTrue);
      expect(p.canPinForEveryone, isFalse);
      expect(p.canSetTag(self: true), isFalse);
    });
  });

  group('member tags', () {
    test('a live change wins, and "cleared" is an answer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tags = container.read(groupMemberTagsProvider.notifier);
      tags.seedFromRoster('g', const [
        ChatMember(userId: 'u', name: 'U', joinedAt: '', tag: 'Designer'),
      ]);
      expect(container.read(groupMemberTagsProvider)['g']?['u'], 'Designer');
      tags.setTag('g', 'u', '');
      expect(container.read(groupMemberTagsProvider)['g']?['u'], '');
    });
  });
}
