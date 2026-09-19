import 'package:ababilx/features/messages/data/chat_endpoints.dart';
import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('independent chat contracts', () {
    test('personal conversation keeps scope and send permission in cache', () {
      final conversation = ChatConversation.fromJson({
        'id': 'personal-1',
        'scope': 'personal',
        'type': 'group',
        'name': 'Friends',
        'created_at': '2026-08-24T00:00:00Z',
        'can_message': false,
      });

      expect(conversation.teamId, isEmpty);
      expect(conversation.isPersonal, isTrue);
      expect(conversation.isGroupConversation, isTrue);
      expect(conversation.canMessage, isFalse);
      expect(conversation.toJson()['scope'], 'personal');
      expect(conversation.toJson()['can_message'], isFalse);
    });

    test('lock_reason from the sidebar is kept for the composer', () {
      final conversation = ChatConversation.fromJson({
        'id': 'dm-1',
        'type': 'dm',
        'created_at': '2026-09-19T00:00:00Z',
        'can_message': false,
        'lock_reason': 'connection_removed',
        'peer_user_id': 'u2',
        'peer_user_name': 'Nila',
      });

      expect(conversation.lockReason, 'connection_removed');
      expect(conversation.isAccountDeleted, isFalse);
      expect(conversation.toJson()['lock_reason'], 'connection_removed');

      final deleted = ChatConversation.fromJson({
        'id': 'dm-2',
        'type': 'dm',
        'created_at': '2026-09-19T00:00:00Z',
        'can_message': false,
        'lock_reason': 'account_deleted',
      });
      expect(deleted.isAccountDeleted, isTrue);
    });

    test('generic endpoint set never falls back to a team route', () {
      const endpoints = ChatEndpoints();

      expect(endpoints.conversations, '/api/chat/conversations');
      expect(endpoints.messages('c1'), '/api/chat/conversations/c1/messages');
      expect(
        endpoints.action('c1', 'e2ee-key'),
        '/api/chat/conversations/c1/e2ee-key',
      );
      expect(endpoints.message('m1'), '/api/chat/messages/m1');
      expect(endpoints.search, '/api/chat/search');
    });

    test('discovery result exposes relationship facts', () {
      final user = ChatUserSummary.fromJson({
        'user_id': 'u2',
        'name': 'Nila',
        'connection': 'accepted',
        'shared_workspace': false,
        'can_message': true,
      });

      expect(user.userId, 'u2');
      expect(user.connection, 'accepted');
      expect(user.canMessage, isTrue);
    });
  });
}
