import 'dart:io';

import 'package:ababilx/features/messages/chat-recipient-picker/chat_recipient_eligible.dart';
import 'package:ababilx/features/chat-lock/data/chat_lock_index.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/share_intake/data/shared_payload.dart';
import 'package:ababilx/features/share_intake/direct-share/direct_share_targets.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _dm(String id, String at, {String request = 'none'}) =>
    ChatConversation(
      id: id,
      teamId: '',
      type: 'dm',
      createdAt: '',
      lastMessageAt: at,
      peerUserId: 'peer-$id',
      peerUserName: 'Peer $id',
      peerUserAvatar: 'https://cdn.example/$id.jpg',
      requestState: request,
    );

void main() {
  test('a share picked from a Direct Share target names its chat', () {
    final payload = SharedPayload.tryParse(
      '{"text":"hi","files":[],"target_conversation_id":"c1"}',
    );
    expect(payload?.targetConversationId, 'c1');
    expect(SharedPayload.tryParse('{"text":"hi"}')?.targetConversationId, '');
  });

  test('a launcher shortcut tap is an open, never a share', () {
    const id = '3f2b9c1e-8a4d-4f6b-9c2e-1d7a5b8e0f34';
    const raw = '{"open_conversation":"$id"}';
    expect(SharedPayload.openConversationId(raw), id);
    // Exported activity: a crafted id must never become a sub-route.
    expect(
      SharedPayload.openConversationId('{"open_conversation":"$id/details"}'),
      isNull,
    );
    expect(SharedPayload.tryParse(raw), isNull);
    expect(SharedPayload.openConversationId('{"text":"x"}'), isNull);
  });

  test('targets: newest first, locked chats and requests left out', () {
    final shareable = shareableConversations(
      dms: [
        _dm('old', '2026-09-01T00:00:00Z'),
        _dm('new', '2026-09-27T00:00:00Z'),
        _dm('locked', '2026-09-26T00:00:00Z'),
        _dm('stranger', '2026-09-25T00:00:00Z', request: 'incoming'),
      ],
      channels: const [],
      locks: {'locked': ChatLockMethod.device},
    );
    final targets = directShareTargets(shareable, 'me');
    expect(targets.map((t) => t['id']), ['new', 'old']);
    expect(targets.first['name'], 'Peer new');
    expect(targets.first['avatarUrl'], 'https://cdn.example/new.jpg');
    expect(targets.first['isGroup'], false);
  });

  test('every launcher alias declares the share-target shortcuts', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final aliases = '<activity-alias'.allMatches(manifest).length;
    expect(aliases, greaterThan(0));
    expect('@xml/share_shortcuts'.allMatches(manifest).length, aliases);
    final xml = File(
      'android/app/src/main/res/xml/share_shortcuts.xml',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/ababilx/app/DirectShareShortcuts.kt',
    ).readAsStringSync();
    const category = 'com.ababilx.app.sharing.CATEGORY_SHARE_TARGET';
    expect(xml, contains(category));
    expect(kotlin, contains(category));
    expect(xml, contains('com.ababilx.app.ShareIntakeActivity'));
  });
}
