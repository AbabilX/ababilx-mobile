import 'dart:async';

import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/attachments/data/models/media_dimensions.dart';
import 'package:ababilx/features/attachments/providers/attachment_providers.dart';
import 'package:ababilx/features/attachments/services/attachment_handle_memory.dart';
import 'package:ababilx/features/messages/chat-timeline/attachment_image_grid.dart';
import 'package:ababilx/features/messages/chat-timeline/attachment_video_tile.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _photo = ChatMessageAttachment(
  id: 'p',
  messageId: 'm',
  fileName: 'wide.jpg',
  fileUrl: 'https://example.invalid/wide.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 100,
  uploadedBy: 'u',
  createdAt: '',
);

const _video = ChatMessageAttachment(
  id: 'v',
  messageId: 'm',
  fileName: 'tall.mp4',
  fileUrl: 'https://example.invalid/tall.mp4',
  contentType: 'video/mp4',
  sizeBytes: 100,
  uploadedBy: 'u',
  createdAt: '',
);

AttachmentHandle _ready(ChatMessageAttachment a, MediaDimensions? size) =>
    AttachmentHandle(
      urlKey: attachmentUrlKey(a.fileUrl),
      remoteUrl: a.fileUrl,
      state: AttachmentTransferState.ready,
      localPath: '/nonexistent/${a.fileName}',
      dimensions: size,
    );

/// A mounted media tile never changes height where that would move what the
/// reader is looking at — the rule that stops a row below the viewport from
/// pushing the visible rows. On screen it may take its real shape.
void main() {
  late AttachmentHandleMemory memory;
  late StreamController<AttachmentHandle> photo;
  late StreamController<AttachmentHandle> video;

  setUp(() {
    memory = AttachmentHandleMemory();
    photo = StreamController<AttachmentHandle>.broadcast();
    video = StreamController<AttachmentHandle>.broadcast();
  });
  tearDown(() async {
    await photo.close();
    await video.close();
  });

  Widget host(Widget child) => ProviderScope(
    overrides: [
      attachmentHandleMemoryProvider.overrideWithValue(memory),
      attachmentHandleProvider(_photo).overrideWith((ref) => photo.stream),
      attachmentHandleProvider(_video).overrideWith((ref) => video.stream),
    ],
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  const soloPhoto = AttachmentImageGrid(images: [_photo]);

  testWidgets('a known shape is the first frame and the last', (tester) async {
    memory.rememberDimensions(
      memory.urlKeyOf(_photo.fileUrl),
      const MediaDimensions(1200, 600),
    );
    await tester.pumpWidget(host(soloPhoto));
    final tile = find.byType(AttachmentImageGrid);
    expect(tester.getSize(tile), const Size(240, 120));

    photo.add(_ready(_photo, const MediaDimensions(1200, 600)));
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(tile), const Size(240, 120));
  });

  testWidgets('a photo on screen takes a shape learned after mount', (
    tester,
  ) async {
    await tester.pumpWidget(host(soloPhoto));
    final tile = find.byType(AttachmentImageGrid);
    expect(tester.getSize(tile).height, 210, reason: 'default frame');

    photo.add(_ready(_photo, const MediaDimensions(1200, 600)));
    await tester.pumpAndSettle();
    expect(tester.getSize(tile).height, 120, reason: 'nothing below it');
  });

  testWidgets('below the screen a late shape waits, so no row moves', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentHandleMemoryProvider.overrideWithValue(memory),
          attachmentHandleProvider(_photo).overrideWith((ref) => photo.stream),
        ],
        child: MaterialApp(
          home: ListView(
            controller: scroll,
            reverse: true,
            children: [
              soloPhoto,
              for (var i = 0; i < 30; i++)
                SizedBox(height: 80, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    final tile = find.byType(AttachmentImageGrid);
    scroll.jumpTo(150); // most of the photo now sits under the viewport
    await tester.pump();
    final row = tester.getRect(find.text('row 3')).top;

    photo.add(_ready(_photo, const MediaDimensions(1200, 600)));
    await tester.pumpAndSettle();
    expect(tester.getSize(tile).height, 210, reason: 'below: held');
    expect(tester.getRect(find.text('row 3')).top, row);

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(tile).height, 120, reason: 'back on screen');
  });

  testWidgets('a video reserves its poster shape before the poster', (
    tester,
  ) async {
    memory.rememberDimensions(
      memory.urlKeyOf(_video.fileUrl),
      const MediaDimensions(1080, 1920),
    );
    await tester.pumpWidget(
      host(const AttachmentVideoTile(attachment: _video, inset: false)),
    );
    final tile = find.byType(AttachmentVideoTile);
    // Tall media keeps the 420 ceiling and narrows (1080/1920 × 420).
    expect(tester.getSize(tile), const Size(236.25, 420));

    video.add(_ready(_video, const MediaDimensions(1080, 1920)));
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(tile), const Size(236.25, 420));
  });
}
