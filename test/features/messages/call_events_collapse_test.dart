import 'package:ababilx/features/messages/chat-timeline/timeline_items.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/voice_call_message_label.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg({
  required String id,
  required String createdAt,
  String type = 'text',
  String userId = 'u1',
  Map<String, dynamic>? meta,
}) => ChatMessage(
  id: id,
  conversationId: 'c1',
  userId: userId,
  body: id,
  createdAt: createdAt,
  messageType: type,
  meta: meta,
);

void main() {
  group('buildChatTimelineItems', () {
    test('leaves a lone call as a message item', () {
      final items = buildChatTimelineItems([
        _msg(id: 'a', createdAt: '2026-09-08T14:00:00Z', type: 'voice_call'),
      ]);
      expect(items, hasLength(1));
      expect(items.single, isA<ChatTimelineMessage>());
    });

    test('collapses same-day consecutive calls into one disclosure', () {
      final items = buildChatTimelineItems([
        _msg(id: '1', createdAt: '2026-09-08T14:33:00Z', type: 'voice_call'),
        _msg(id: '2', createdAt: '2026-09-08T14:34:00Z', type: 'voice_call'),
        _msg(id: '3', createdAt: '2026-09-08T14:35:00Z', type: 'voice_call'),
      ]);
      expect(items, hasLength(1));
      final run = items.single as ChatTimelineCallEvents;
      expect(run.messages.map((m) => m.id), ['1', '2', '3']);
    });

    test('does not collapse across a day boundary', () {
      // Noon UTC on days two apart — different local calendar days in every
      // offset that Flutter tests commonly run under.
      final items = buildChatTimelineItems([
        _msg(id: '1', createdAt: '2026-09-01T12:00:00Z', type: 'voice_call'),
        _msg(id: '2', createdAt: '2026-09-03T12:00:00Z', type: 'voice_call'),
      ]);
      expect(items, hasLength(2));
      expect(items.every((i) => i is ChatTimelineMessage), isTrue);
    });

    test('a non-call message breaks the run', () {
      final items = buildChatTimelineItems([
        _msg(id: '1', createdAt: '2026-09-08T14:00:00Z', type: 'voice_call'),
        _msg(id: '2', createdAt: '2026-09-08T14:01:00Z', type: 'text'),
        _msg(id: '3', createdAt: '2026-09-08T14:02:00Z', type: 'voice_call'),
        _msg(id: '4', createdAt: '2026-09-08T14:03:00Z', type: 'group_call'),
      ]);
      expect(items, hasLength(3));
      expect(items[0], isA<ChatTimelineMessage>());
      expect(items[1], isA<ChatTimelineMessage>());
      expect(items[2], isA<ChatTimelineCallEvents>());
      final run = items[2] as ChatTimelineCallEvents;
      expect(run.messages.map((m) => m.id), ['3', '4']);
    });

    test('leaves a lone system event as a message item', () {
      final items = buildChatTimelineItems([
        _msg(id: 'a', createdAt: '2026-09-08T14:00:00Z', type: 'system'),
      ]);
      expect(items, hasLength(1));
      expect(items.single, isA<ChatTimelineMessage>());
    });

    test(
      'collapses same-day consecutive system events until a real message',
      () {
        final items = buildChatTimelineItems([
          _msg(id: '1', createdAt: '2026-09-08T14:00:00Z', type: 'system'),
          _msg(id: '2', createdAt: '2026-09-08T14:01:00Z', type: 'system'),
          _msg(id: '3', createdAt: '2026-09-08T14:02:00Z', type: 'system'),
          _msg(id: '4', createdAt: '2026-09-08T14:03:00Z', type: 'text'),
          _msg(id: '5', createdAt: '2026-09-08T14:04:00Z', type: 'system'),
          _msg(id: '6', createdAt: '2026-09-08T14:05:00Z', type: 'system'),
        ]);
        expect(items, hasLength(3));
        final first = items[0] as ChatTimelineGroupEvents;
        expect(first.messages.map((m) => m.id), ['1', '2', '3']);
        expect(items[1], isA<ChatTimelineMessage>());
        final second = items[2] as ChatTimelineGroupEvents;
        expect(second.messages.map((m) => m.id), ['5', '6']);
      },
    );

    test('does not collapse system events across a day boundary', () {
      final items = buildChatTimelineItems([
        _msg(id: '1', createdAt: '2026-09-01T12:00:00Z', type: 'system'),
        _msg(id: '2', createdAt: '2026-09-03T12:00:00Z', type: 'system'),
      ]);
      expect(items, hasLength(2));
      expect(items.every((i) => i is ChatTimelineMessage), isTrue);
    });
  });

  group('voiceCallHistoryLabel', () {
    test('uses Incoming/Outgoing for ended calls', () {
      final ended = _msg(
        id: 'e',
        createdAt: '2026-09-08T14:00:00Z',
        type: 'voice_call',
        userId: 'caller',
        meta: {
          'status': 'ended',
          'caller_id': 'caller',
          'duration_seconds': 12,
        },
      );
      expect(voiceCallHistoryLabel(ended, 'caller'), 'Outgoing voice call');
      expect(voiceCallHistoryLabel(ended, 'peer'), 'Incoming voice call');
    });

    test('keeps kind label for failed calls', () {
      final failed = _msg(
        id: 'f',
        createdAt: '2026-09-08T14:00:00Z',
        type: 'voice_call',
        meta: {'status': 'failed', 'caller_id': 'caller'},
      );
      expect(voiceCallHistoryLabel(failed, 'peer'), 'Voice call failed');
    });
  });
}
