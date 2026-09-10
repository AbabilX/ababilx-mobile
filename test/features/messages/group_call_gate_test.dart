import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';

ChatConversation _conversation(
  String type, {
  String scope = 'workspace',
  bool canMessage = true,
}) => ChatConversation.fromJson({
  'id': 'c1',
  'scope': scope,
  'type': type,
  'can_message': canMessage,
});

void main() {
  group('group call button', () {
    test('a workspace channel has one', () {
      expect(_conversation('channel').canGroupCall, isTrue);
    });

    test('a personal group has one too', () {
      // The server has served personal group calls since migration 0110; the
      // header only ever asked isChannel, so these groups showed no button.
      expect(_conversation('group', scope: 'personal').canGroupCall, isTrue);
    });

    test('a DM never does: its call is the peer-to-peer voice call', () {
      expect(_conversation('dm', scope: 'personal').canGroupCall, isFalse);
    });

    test('a webhook feed never does, even parsed without can_message', () {
      final feed = ChatConversation.fromJson({
        'id': 'c1',
        'team_id': 't1',
        'type': 'webhook',
      });
      expect(feed.canMessage, isTrue);
      expect(feed.canGroupCall, isFalse);
    });

    test('a group you cannot post into has none', () {
      expect(
        _conversation('group', scope: 'personal', canMessage: false)
            .canGroupCall,
        isFalse,
      );
    });
  });
}
