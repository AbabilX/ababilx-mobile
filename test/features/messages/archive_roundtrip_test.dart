import 'dart:typed_data';

import 'package:ababilx/features/messages/archive/archive_frames.dart';
import 'package:ababilx/features/messages/archive/archive_key.dart';
import 'package:ababilx/features/messages/archive/archive_reader.dart'
    show ArchiveReader, ArchiveTruncatedError;
import 'package:ababilx/features/messages/archive/archive_writer.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(int i, {String? parentId}) => ChatMessage(
  id: 'm$i',
  conversationId: 'c1',
  userId: 'u1',
  body: 'message body $i',
  parentId: parentId,
  createdAt: '2026-09-0${(i % 9) + 1}T00:00:00Z',
  attachments: const [
    ChatMessageAttachment(
      id: 'a1',
      messageId: 'm0',
      fileUrl: 'https://cdn.example/a.jpg',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 10,
      uploadedBy: 'u1',
      createdAt: '2026-09-01T00:00:00Z',
    ),
  ],
);

Future<List<ArchiveChunk>> _write(
  List<ArchiveFrame> frames, {
  required int chunkBytes,
}) async {
  final key = await ArchiveKey.derive(
    Uint8List.fromList(List<int>.generate(32, (i) => i)),
    ArchiveKey.newSalt(),
  );
  final chunks = <ArchiveChunk>[];
  final writer = ArchiveWriter(
    key: key,
    chunkBytes: chunkBytes,
    onChunk: (_, chunk) async => chunks.add(chunk),
  );
  for (final frame in frames) {
    await writer.add(frame);
  }
  await writer.close();
  return chunks;
}

void main() {
  test('round-trips a history across many chunks', () async {
    final scalar = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final salt = ArchiveKey.newSalt();
    final key = await ArchiveKey.derive(scalar, salt);

    final frames = <ArchiveFrame>[
      ArchiveFrame.headerFrame(createdAtMs: 1, deviceId: 'dev'),
      // A thread reply is included deliberately: the local `page` read filters
      // thread_root_id IS NULL, so a backup built on it would silently drop
      // exactly this row.
      ...List.generate(
        400,
        (i) => ArchiveFrame.messageFrame(
          _msg(i, parentId: i % 7 == 0 ? 'm0' : null),
        ),
      ),
    ];

    final chunks = <ArchiveChunk>[];
    final writer = ArchiveWriter(
      key: key,
      chunkBytes: 1024,
      onChunk: (_, chunk) async => chunks.add(chunk),
    );
    for (final frame in frames) {
      await writer.add(frame);
    }
    await writer.close();
    expect(chunks.length, greaterThan(1), reason: 'must actually chunk');

    final read = <ChatMessage>[];
    final reader = ArchiveReader(
      key: key,
      onFrame: (frame) async {
        final msg = frame.asMessage();
        if (msg != null) read.add(msg);
      },
    );
    for (final chunk in chunks) {
      await reader.addChunk(chunk);
    }
    await reader.finish();

    expect(read.length, 400);
    expect(read.first.body, 'message body 0');
    expect(read.last.body, 'message body 399');
    expect(read.where((m) => m.parentId != null), isNotEmpty);
    expect(read.first.attachments.single.fileName, 'a.jpg');
  });

  test('a dropped tail chunk is not silently a shorter history', () async {
    final scalar = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final key = await ArchiveKey.derive(scalar, ArchiveKey.newSalt());
    final chunks = <ArchiveChunk>[];
    final writer = ArchiveWriter(
      key: key,
      chunkBytes: 512,
      onChunk: (_, chunk) async => chunks.add(chunk),
    );
    for (var i = 0; i < 200; i++) {
      await writer.add(ArchiveFrame.messageFrame(_msg(i)));
    }
    await writer.close();

    final reader = ArchiveReader(key: key, onFrame: (_) async {});
    for (final chunk in chunks.take(chunks.length - 1)) {
      await reader.addChunk(chunk);
    }
    // gzip.decode accepts a truncated member and returns what it inflated, so
    // the terminator frame is the only thing that can catch this. Without it a
    // half-uploaded archive restores as a shorter, plausible history.
    expect(reader.finish(), throwsA(isA<ArchiveTruncatedError>()));
  });

  test('reordered chunks fail the tag', () async {
    final scalar = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final key = await ArchiveKey.derive(scalar, ArchiveKey.newSalt());
    final chunks = await _write(
      List.generate(200, (i) => ArchiveFrame.messageFrame(_msg(i))),
      chunkBytes: 512,
    );
    expect(chunks.length, greaterThan(2));
    final reader = ArchiveReader(key: key, onFrame: (_) async {});
    await expectLater(() async {
      await reader.addChunk(chunks[1]);
      await reader.addChunk(chunks[0]);
    }(), throwsA(anything));
  });

  test('an unknown frame type is skipped, not fatal', () async {
    final key = await ArchiveKey.derive(
      Uint8List.fromList(List<int>.generate(32, (i) => i)),
      ArchiveKey.newSalt(),
    );
    final chunks = <ArchiveChunk>[];
    final writer = ArchiveWriter(
      key: key,
      onChunk: (_, chunk) async => chunks.add(chunk),
    );
    await writer.add(const ArchiveFrame('sticker_pack_from_the_future', {}));
    await writer.add(ArchiveFrame.messageFrame(_msg(1)));
    await writer.close();

    final seen = <String>[];
    final reader = ArchiveReader(
      key: key,
      onFrame: (frame) async => seen.add(frame.type),
    );
    for (final chunk in chunks) {
      await reader.addChunk(chunk);
    }
    await reader.finish();
    expect(seen, ['sticker_pack_from_the_future', 'msg']);
  });
}
