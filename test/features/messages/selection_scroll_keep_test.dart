import 'dart:async';

import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/providers/attachment_providers.dart';
import 'package:ababilx/features/messages/chat-select/message_selection.dart';
import 'package:ababilx/features/messages/chat-timeline/chat_timeline.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _conv = 'c1';

ChatMessageAttachment _photo(int i) => ChatMessageAttachment(
  id: 'a$i',
  messageId: 'm$i',
  fileName: 'p$i.jpg',
  fileUrl: 'https://example.invalid/p$i.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 100,
  uploadedBy: 'alice',
  createdAt: '',
);

final _messages = [
  for (var i = 0; i < 60; i++)
    ChatMessage(
      id: 'm$i',
      conversationId: _conv,
      userId: i.isEven ? 'alice' : 'me',
      body: i % 3 == 0 ? '' : 'message $i',
      attachments: i % 3 == 0 ? [_photo(i)] : const [],
      createdAt:
          '2026-09-12T${(6 + i ~/ 60).toString().padLeft(2, '0')}:'
          '${(i % 60).toString().padLeft(2, '0')}:00Z',
    ),
];

class _Chat extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    dms: const [
      ChatConversation(
        id: _conv,
        teamId: '',
        createdAt: '2026-09-12T06:00:00Z',
        type: 'dm',
        name: 'Alice',
        peerUserId: 'alice',
      ),
    ],
    feeds: {_conv: ChatFeed(messages: _messages)},
  );

  @override
  Future<bool> hydrateFeedFromCache(
    String conversationId, {
    String? threadRootId,
  }) async => true;

  @override
  Future<void> loadFeed(
    String conversationId, {
    String? threadRootId,
    bool force = false,
  }) async {}

  @override
  Future<void> loadMoreFeed(
    String conversationId, {
    String? threadRootId,
  }) async {}

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  void prefetchThreadSummaries(String conversationId) {}
}

/// The `message N` label of every body the list has built, bottom first.
List<String> _builtLabels() =>
    find.textContaining('message ').evaluate().map((e) {
      final w = e.widget;
      final plain = w is Text
          ? (w.data ?? w.textSpan!.toPlainText())
          : (w as RichText).text.toPlainText();
      return RegExp(r'message \d+').firstMatch(plain)!.group(0)!;
    }).toList();

Future<void> _settle(WidgetTester tester) async {
  // Rows run a repeating pulse, so the tree never settles on its own.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // The bug: Select swapped the header and the composer for the two bars,
  // the Column could not match the list between them, and a new list came
  // up at offset 0 — the newest message — every time the mode opened or
  // closed.
  testWidgets('Select and closing it keep the reader where they were', (
    tester,
  ) async {
    final never = StreamController<AttachmentHandle>.broadcast();
    addTearDown(never.close);
    final container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(_Chat.new),
        for (final m in _messages)
          for (final a in m.attachments)
            attachmentHandleProvider(a).overrideWith((ref) => never.stream),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ChatTimeline(
              conversationId: _conv,
              header: SizedBox(height: 56, child: Text('HEADER')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final controller = tester
        .widget<ListView>(find.byType(ListView).first)
        .controller!;
    controller.jumpTo(2500);
    await tester.pump();
    final labels = _builtLabels();
    final label = labels[labels.length ~/ 2];
    final anchor = find.textContaining(label).first;
    final top = tester.getRect(anchor).top;

    await tester.longPress(anchor);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Select'));
    await _settle(tester);

    expect(container.read(messageSelectionProvider).ids, {
      'm${label.split(' ').last}',
    });
    expect(controller.offset, closeTo(2500, 1));
    // The bars differ in height from the header and composer they replace,
    // so the row may move by that much — never off the screen.
    expect(tester.getRect(anchor).top, closeTo(top, 80));

    container.read(messageSelectionProvider.notifier).clear();
    await _settle(tester);
    expect(controller.offset, closeTo(2500, 1));
    expect(tester.getRect(anchor).top, closeTo(top, 1));

    // The typing provider runs a periodic timer; it has to be gone before
    // the test ends.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
