import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/notifications/notification_router.dart';

void main() {
  group('call notification routing', () {
    test('voice call opens its conversation, never the call screen', () {
      expect(
        NotificationRouter.pathForData({
          'type': 'voice_call',
          'conversation_id': 'dm-1',
        }),
        '/messages/dm-1',
      );
    });

    test('group call opens its conversation, never the join screen', () {
      expect(
        NotificationRouter.pathForData({
          'type': 'group_call',
          'conversation_id': 'channel-1',
        }),
        '/messages/channel-1',
      );
    });

    test('call notification without a conversation lands on messages', () {
      expect(
        NotificationRouter.pathForData({'type': 'voice_call'}),
        '/messages',
      );
    });
  });
}
