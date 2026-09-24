import 'package:ababilx/features/messages/chat-timeline/group_event_label.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _system({
  required String event,
  String actorId = 'alice',
  String actorName = 'Alice',
  String? targetId,
  String? targetName,
  String? value,
  String body = 'fallback body',
}) => ChatMessage(
  id: 'm1',
  conversationId: 'c1',
  userId: actorId,
  body: body,
  createdAt: '2026-09-25T00:00:00Z',
  messageType: 'system',
  meta: {
    'event': event,
    'actor_id': actorId,
    'actor_name': actorName,
    if (targetId != null) 'target_id': targetId,
    if (targetName != null) 'target_name': targetName,
    if (value != null) 'value': value,
  },
);

void main() {
  test('uses You when the viewer is the actor', () {
    expect(
      groupEventLabel(
        _system(event: 'avatar_changed', actorId: 'me', value: 'https://x'),
        'me',
      ),
      'You changed the group photo',
    );
  });

  test('uses you when the viewer is the target', () {
    expect(
      groupEventLabel(
        _system(
          event: 'member_added',
          targetId: 'me',
          targetName: 'Murad',
        ),
        'me',
      ),
      'Alice added you',
    );
  });

  test('name_changed quotes the new name', () {
    expect(
      groupEventLabel(
        _system(event: 'name_changed', value: 'Weekend crew'),
        'me',
      ),
      'Alice changed the group name to "Weekend crew"',
    );
  });

  test('falls back to body for unknown events', () {
    expect(
      groupEventLabel(
        _system(event: 'future_thing', body: 'Alice did something'),
        'me',
      ),
      'Alice did something',
    );
  });

  test('privacy_changed reads on/off', () {
    expect(
      groupEventLabel(_system(event: 'privacy_changed', value: 'on'), 'me'),
      'Alice turned on group privacy',
    );
    expect(
      groupEventLabel(_system(event: 'privacy_changed', value: 'off'), 'me'),
      'Alice turned off group privacy',
    );
  });
}
