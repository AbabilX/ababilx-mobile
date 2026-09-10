import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/attachments/providers/attachment_providers.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/chat-timeline/attachment_image_grid.dart';

void main() {
  for (final withCaption in [false, true]) {
    testWidgets('media completion preserves visible row (caption=$withCaption)', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('media-scroll-audit-');
      final file = File('${dir.path}/landscape.png');
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 1200, 600),
          Paint()..color = Colors.blue,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(1200, 600);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      const attachment = ChatMessageAttachment(
        id: 'a',
        messageId: 'm',
        fileName: 'landscape.png',
        fileUrl: 'https://example.invalid/a',
        contentType: 'image/png',
        sizeBytes: 100,
        uploadedBy: 'u',
        createdAt: '',
      );
      final stream = StreamController<AttachmentHandle>.broadcast();
      final scroll = ScrollController(initialScrollOffset: 1100);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attachmentHandleProvider(
              attachment,
            ).overrideWith((ref) => stream.stream),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 600,
                  child: ListView.builder(
                    controller: scroll,
                    reverse: true,
                    itemCount: 40,
                    itemBuilder: (_, i) => Column(
                      children: [
                        Text('row-$i'),
                        AttachmentImageGrid(
                          images: const [attachment],
                          withCaption: withCaption,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(
          FileImage(file),
          tester.element(find.byType(Scaffold)),
        ),
      );
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      final marker = find.text('row-6');
      final before = tester.getTopLeft(marker).dy;
      final beforeOffset = scroll.offset;
      final beforeSize = tester.getSize(find.byType(AttachmentImageGrid).first);
      stream.add(
        AttachmentHandle(
          urlKey: 'a',
          remoteUrl: attachment.fileUrl,
          state: AttachmentTransferState.ready,
          localPath: file.path,
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      final after = tester.getTopLeft(marker).dy;
      final afterSize = tester.getSize(find.byType(AttachmentImageGrid).first);
      expect(afterSize, beforeSize);
      expect(scroll.offset, beforeOffset);
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      await stream.close();
      dir.deleteSync(recursive: true);
      expect(
        (after - before).abs(),
        lessThan(1),
        reason:
            'Download completion must not move a visible row under a held finger',
      );
    });
  }
}
