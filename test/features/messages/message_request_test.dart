import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation_json.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> dm({String? requestState}) => {
  'id': 'c1',
  'team_id': '',
  'scope': 'personal',
  'type': 'dm',
  'created_at': '2026-08-26T10:00:00Z',
  'peer_user_id': 'u2',
  'peer_user_name': 'Ada',
  'request_state': ?requestState,
};

void main() {
  group('message request state', () {
    test('an incoming request raises the bar', () {
      final c = ChatConversation.fromJson(dm(requestState: 'incoming'));
      expect(c.isIncomingRequest, isTrue);
    });

    test('the sender side does not get the bar', () {
      final c = ChatConversation.fromJson(dm(requestState: 'outgoing'));
      expect(c.isIncomingRequest, isFalse);
    });

    test('a settled thread does not get the bar', () {
      final c = ChatConversation.fromJson(dm(requestState: 'none'));
      expect(c.isIncomingRequest, isFalse);
    });

    // A server that predates request_state, or a workspace DM, sends nothing.
    // Defaulting to a bar would lock the composer on every existing thread.
    test('a missing field means no request', () {
      final c = ChatConversation.fromJson(dm());
      expect(c.requestState, 'none');
      expect(c.isIncomingRequest, isFalse);
    });

    test('accepting clears the bar locally', () {
      final c = ChatConversation.fromJson(dm(requestState: 'incoming'));
      expect(c.copyWith(requestState: 'none').isIncomingRequest, isFalse);
    });

    test('request state survives the local sidebar cache', () {
      final c = ChatConversation.fromJson(dm(requestState: 'incoming'));
      expect(ChatConversation.fromJson(c.toJson()).isIncomingRequest, isTrue);
    });
  });
}
