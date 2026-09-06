import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';

ChatConversation _conversation(String type) => ChatConversation(
  id: 'c1',
  teamId: 't1',
  type: type,
  createdAt: '2026-09-07T00:00:00Z',
);

void main() {
  group('webhook feed conversation', () {
    test('is a group in every respect except sending', () {
      final feed = _conversation('webhook');
      expect(feed.isWebhook, isTrue);
      // Roster, title and avatars all hang off this one predicate, which is
      // why a feed has to answer yes to it.
      expect(feed.isGroupConversation, isTrue);
      expect(feed.isChannel, isFalse);
      expect(feed.displayTitle(null), 'Group');
    });

    test('is never end-to-end encrypted', () {
      // Mirrors e2eeEligible on the server: a workspace room is plaintext, and
      // a client that disagreed would send a body the server answers with 400.
      expect(_conversation('webhook').isEncrypted, isFalse);
    });

    test('read-only comes from the server, not from the type', () {
      // can_message is the whole lock. Nothing on the client re-derives it, so
      // a feed parsed without the field must not lock itself.
      final locked = ChatConversation.fromJson({
        'id': 'c1',
        'team_id': 't1',
        'type': 'webhook',
        'can_message': false,
      });
      expect(locked.canMessage, isFalse);
      expect(_conversation('webhook').canMessage, isTrue);
    });
  });

  group('webhook message', () {
    ChatMessage message(Map<String, dynamic> extra) => ChatMessage.fromJson({
      'id': 'm1',
      'conversation_id': 'c1',
      'message_type': 'webhook',
      'body': 'Deployment completed',
      ...extra,
    });

    test('takes its display name from meta, not from a sender', () {
      final msg = message({
        'meta': {'source_name': ' Deploys '},
      });
      expect(msg.isWebhook, isTrue);
      expect(msg.userId, isEmpty);
      expect(msg.webhookSourceName, 'Deploys');
    });

    test('falls back when the feed name is missing or blank', () {
      expect(message(const {}).webhookSourceName, isNull);
      expect(
        message({
          'meta': {'source_name': '   '},
        }).webhookSourceName,
        isNull,
      );
    });
  });
}
