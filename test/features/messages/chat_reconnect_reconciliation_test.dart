import 'dart:async';

import 'package:ababilx/features/messages/data/chat_message_merge.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/data/request_single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reconnect neither refetches twice nor appends old messages at end',
    () async {
      var timeline = [for (var i = 1; i <= 10; i++) message(i)];
      final responseGate = Completer<List<ChatMessage>>();
      final requests = RequestSingleFlight<List<ChatMessage>>();
      var executions = 0;

      Future<List<ChatMessage>> reconnectFetch() =>
          requests.run('room|first', () {
            executions++;
            return responseGate.future;
          });

      final screenRefresh = reconnectFetch();
      final websocketRefresh = reconnectFetch();

      // A live message lands while the reconnect page is still in flight.
      timeline = canonicalChatMessages([...timeline, message(11)]);
      // The server page overlaps seven messages already visible and arrives in
      // newest-first API order, which used to be appended after message 11.
      responseGate.complete([for (var i = 10; i >= 4; i--) message(i)]);

      final first = await screenRefresh;
      final second = await websocketRefresh;
      timeline = canonicalChatMessages([...timeline, ...first, ...second]);

      expect(executions, 1);
      expect(timeline.map((item) => item.id), [
        for (var i = 1; i <= 11; i++) 'm$i',
      ]);
      expect(timeline.map((item) => item.id).toSet().length, timeline.length);
    },
  );
}

ChatMessage message(int sequence) => ChatMessage(
  id: 'm$sequence',
  conversationId: 'room',
  userId: 'sender',
  body: 'message $sequence',
  createdAt: DateTime.utc(2026, 8, 29, 12, 0, sequence).toIso8601String(),
);
