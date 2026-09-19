import 'dart:io';
import 'dart:ui' as ui;

import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/data/models/media_dimensions.dart';
import 'package:ababilx/features/attachments/services/attachment_handle_memory.dart';
import 'package:ababilx/features/attachments/services/media_measure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AttachmentHandle _handle(
  String key, {
  AttachmentTransferState state = AttachmentTransferState.ready,
  MediaDimensions? size,
}) => AttachmentHandle(
  urlKey: key,
  remoteUrl: 'https://cdn.example.com/$key',
  state: state,
  localPath: '/tmp/$key.jpg',
  dimensions: size,
);

void main() {
  test('a later handle without a size keeps the size already known', () {
    final memory = AttachmentHandleMemory();
    memory.remember(_handle('k', size: const MediaDimensions(4, 3)));
    memory.remember(_handle('k', state: AttachmentTransferState.downloading));

    expect(memory.handleOf('k')?.dimensions, const MediaDimensions(4, 3));
  });

  test('the oldest entry goes first once full', () {
    final memory = AttachmentHandleMemory(capacity: 2);
    memory.remember(_handle('a'));
    memory.remember(_handle('b'));
    memory.remember(_handle('a')); // touched again: now the newest
    memory.remember(_handle('c'));

    expect(memory.handleOf('b'), isNull);
    expect(memory.handleOf('a'), isNotNull);
    expect(memory.handleOf('c'), isNotNull);
  });

  test('forgetting everything can keep the shapes', () {
    final memory = AttachmentHandleMemory();
    memory.remember(_handle('k', size: const MediaDimensions(4, 3)));

    memory.forget(null, keepDimensions: true);
    expect(memory.handleOf('k'), isNull);
    expect(memory.dimensionsOf('k'), isNotNull);

    memory.forget(null, keepDimensions: false);
    expect(memory.dimensionsOf('k'), isNull);
  });

  test('url keys are memoised and match the store key', () {
    final memory = AttachmentHandleMemory();
    const url = 'https://CDN.example.com/a.jpg?v=2';
    expect(memory.urlKeyOf(url), memory.urlKeyOf(url));
    expect(memory.urlKeyOf(url), isNotEmpty);
  });

  testWidgets('a picture is measured from its header, not decoded', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('ababilx-measure-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/wide.png');
    final size = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 300, 100),
        Paint()..color = Colors.red,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(300, 100);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      return measureMediaFile(file.path, video: false);
    });
    expect(size, const MediaDimensions(300, 100));

    final junk = File('${dir.path}/junk.png')..writeAsStringSync('nope');
    final none = await tester.runAsync(
      () => measureMediaFile(junk.path, video: false),
    );
    expect(none, isNull, reason: 'unreadable keeps the default frame');
  });
}
