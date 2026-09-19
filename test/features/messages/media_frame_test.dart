import 'package:ababilx/features/attachments/data/models/media_dimensions.dart';
import 'package:ababilx/features/messages/chat-timeline/media_frame.dart';
import 'package:ababilx/features/messages/chat-timeline/message_row_pulse.dart';
import 'package:ababilx/features/messages/chat-timeline/timeline_items.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(
  String id, {
  MessageSendStatus status = MessageSendStatus.sent,
}) => ChatMessage(
  id: id,
  conversationId: 'c',
  userId: 'u',
  body: id,
  createdAt: '2026-09-19T10:00:00Z',
  sendStatus: status,
);

void main() {
  group('soloMediaHeight', () {
    test('an unmeasured file gets the default frame', () {
      expect(soloMediaHeight(null, width: 240), 210);
    });
    test('the file decides, inside Signal\'s bounds', () {
      const wide = MediaDimensions(1200, 600);
      const tall = MediaDimensions(1080, 1920);
      const panorama = MediaDimensions(4000, 500);
      expect(soloMediaHeight(wide, width: 240), 120);
      expect(soloMediaHeight(tall, width: 240), 420, reason: 'ceiling');
      expect(soloMediaHeight(panorama, width: 240), 100, reason: 'floor');
    });
  });

  group('displaySizedImage', () {
    const source = AssetImage('photo.jpg');
    test('decodes just enough to cover the box on this screen', () {
      final image = displaySizedImage(
        source,
        box: const Size(240, 120),
        size: const MediaDimensions(4000, 2000),
        devicePixelRatio: 3,
      );
      expect(image, isA<ResizeImage>());
      expect((image as ResizeImage).width, 720);
    });
    test('never upscales, and leaves an unmeasured file alone', () {
      expect(
        displaySizedImage(
          source,
          box: const Size(240, 120),
          size: const MediaDimensions(300, 150),
          devicePixelRatio: 3,
        ),
        same(source),
      );
      expect(
        displaySizedImage(
          source,
          box: const Size(240, 120),
          size: null,
          devicePixelRatio: 3,
        ),
        same(source),
      );
    });
  });

  test('a new message keeps every existing row\'s key', () {
    final before = timelineRowKeys([
      ChatTimelineMessage(_message('a')),
      ChatTimelineMessage(_message('b')),
    ]);
    final after = timelineRowKeys([
      ChatTimelineMessage(_message('a')),
      ChatTimelineMessage(_message('b')),
      ChatTimelineMessage(_message('c')),
    ]);
    expect(before.keys, ['b', 'a'], reason: 'position 0 is the newest');
    expect(after.keys, ['c', 'b', 'a']);
    expect(after.positions['b'], before.positions['b']! + 1);

    final dup = timelineRowKeys([
      ChatTimelineMessage(_message('x')),
      ChatTimelineMessage(_message('x')),
    ]);
    expect(dup.keys.toSet(), hasLength(2), reason: 'no two rows share a key');
  });

  testWidgets('only a sending bubble keeps a ticker running', (tester) async {
    await tester.pumpWidget(_PulseHost(_message('m')));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(
      _PulseHost(_message('m', status: MessageSendStatus.sending)),
    );
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(_PulseHost(_message('m')));
    expect(tester.binding.transientCallbackCount, 0);
  });
}

class _PulseHost extends StatefulWidget {
  const _PulseHost(this.message);
  final ChatMessage message;

  @override
  State<_PulseHost> createState() => _PulseHostState();
}

class _PulseHostState extends State<_PulseHost>
    with SingleTickerProviderStateMixin, MessageRowPulse {
  @override
  ChatMessage get pulsedMessage => widget.message;

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: pulse, child: const SizedBox());
}
