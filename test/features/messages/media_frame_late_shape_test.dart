import 'dart:async';

import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/data/models/media_dimensions.dart';
import 'package:ababilx/features/attachments/providers/attachment_providers.dart';
import 'package:ababilx/features/messages/chat-timeline/media_frame_lock.dart';
import 'package:ababilx/features/messages/chat-timeline/media_frame_shift.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _photo = ChatMessageAttachment(
  id: 'a1',
  messageId: 'm1',
  fileName: 'p.jpg',
  fileUrl: 'https://example.invalid/p.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 100,
  uploadedBy: 'alice',
  createdAt: '',
);

const _tall = MediaDimensions(900, 1600);

AttachmentHandle _ready(MediaDimensions? size) => AttachmentHandle(
  urlKey: 'k',
  remoteUrl: _photo.fileUrl,
  state: AttachmentTransferState.ready,
  dimensions: size,
);

/// Draws the locked shape as its height: 100 unknown, 300 for [_tall].
class _Tile extends ConsumerStatefulWidget {
  const _Tile();

  @override
  ConsumerState<_Tile> createState() => _TileState();
}

class _TileState extends ConsumerState<_Tile> with MediaFrameLock {
  @override
  ChatMessageAttachment get framedAttachment => _photo;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('tile'),
    height: lockedDimensions == null ? 100 : 300,
  );
}

Future<(StreamController<AttachmentHandle>, ScrollController)> _pump(
  WidgetTester tester,
) async {
  final handles = StreamController<AttachmentHandle>.broadcast();
  addTearDown(handles.close);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attachmentHandleProvider(_photo).overrideWith((ref) => handles.stream),
      ],
      child: MaterialApp(
        home: ListView(
          controller: scroll,
          reverse: true,
          children: [
            const _Tile(),
            for (var i = 0; i < 40; i++)
              SizedBox(height: 80, child: Text('$i')),
          ],
        ),
      ),
    ),
  );
  return (handles, scroll);
}

double _height(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('tile'))).height;

void main() {
  // The bug: a photo arriving with the chat open mounted before its bytes,
  // locked the default square, and kept it until the chat was reopened.
  testWidgets('a photo on screen takes its shape once it downloads', (
    tester,
  ) async {
    final (handles, _) = await _pump(tester);
    handles.add(_ready(null));
    await tester.pump();
    expect(_height(tester), 100);

    handles.add(_ready(_tall));
    await tester.pumpAndSettle();
    expect(_height(tester), 300);
  });

  testWidgets('below the viewport it waits, so visible rows never move', (
    tester,
  ) async {
    final (handles, scroll) = await _pump(tester);
    scroll.jumpTo(60); // the photo's top 40 px now sit under the viewport
    await tester.pump();
    final anchor = tester.getRect(find.text('5')).top;

    handles.add(_ready(_tall));
    await tester.pumpAndSettle();
    expect(_height(tester), 100);
    expect(tester.getRect(find.text('5')).top, anchor);

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_height(tester), 300);
  });

  group('canResizeMediaFrame, reverse list', () {
    const view = Rect.fromLTWH(0, 100, 400, 600); // 100..700
    bool can(Rect tile, {bool scrolling = false}) => canResizeMediaFrame(
      direction: AxisDirection.up,
      tile: tile,
      viewport: view,
      scrolling: scrolling,
    );

    test('on screen and idle', () {
      expect(can(const Rect.fromLTWH(0, 400, 200, 200)), isTrue);
    });
    test('on screen while scrolling waits', () {
      expect(
        can(const Rect.fromLTWH(0, 400, 200, 200), scrolling: true),
        isFalse,
      );
    });
    test('partly below the viewport waits', () {
      expect(can(const Rect.fromLTWH(0, 600, 200, 200)), isFalse);
    });
    test('wholly above the viewport, even mid-fling', () {
      expect(
        can(const Rect.fromLTWH(0, -150, 200, 200), scrolling: true),
        isTrue,
      );
    });
  });
}
