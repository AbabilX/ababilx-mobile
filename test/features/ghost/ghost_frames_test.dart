import 'dart:typed_data';

import 'package:ababilx/features/ghost/protocol/ghost_file_assembler.dart';
import 'package:ababilx/features/ghost/protocol/ghost_frames.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GhostFrame', () {
    test('round-trips every frame', () {
      final frames = <GhostFrame>[
        const GhostTextFrame(id: 'm1', body: 'hi 👋', at: 42),
        const GhostFileHeader(
          id: 'f1',
          name: 'a.jpg',
          mime: 'image/jpeg',
          size: 40000,
          at: 7,
        ),
        const GhostTypingFrame(on: true),
        const GhostBurnFrame(),
        const GhostLeaveFrame(),
        const GhostPingFrame(),
      ];
      for (final frame in frames) {
        final decoded = GhostFrame.decode(frame.encode());
        expect(decoded.runtimeType, frame.runtimeType);
        expect(decoded!.encode(), frame.encode());
      }
    });

    test('rejects garbage without throwing', () {
      for (final raw in [
        '',
        'not json',
        '[]',
        '{"t":"nope"}',
        '{"t":"msg","id":"m","body":""}',
        '{"t":"msg","body":"no id"}',
        '{"t":"file","id":"f","size":0}',
        '{"t":"file","id":"f","size":${maxGhostFileBytes + 1}}',
        '{"t":"msg","id":"m","body":"${'x' * (maxBodyChars + 1)}"}',
      ]) {
        expect(GhostFrame.decode(raw), isNull, reason: raw);
      }
    });

    test('file names lose their path and control characters', () {
      expect(safeGhostFileName('../../etc/passwd'), 'passwd');
      expect(safeGhostFileName(r'C:\Users\x\report.pdf'), 'report.pdf');
      expect(safeGhostFileName('..hidden'), 'hidden');
      expect(safeGhostFileName('a\u0000b<c>.txt'), 'abc.txt');
      expect(safeGhostFileName('///'), 'file');
    });

    test('chunk count covers the last partial chunk', () {
      const h = GhostFileHeader(
        id: 'f',
        name: 'x',
        mime: 'x',
        size: ghostChunkBytes * 2 + 1,
        at: 0,
      );
      expect(h.chunkCount, 3);
    });
  });

  group('GhostFileAssembler', () {
    GhostFileHeader header(int size) => GhostFileHeader(
      id: 'f',
      name: 'x.bin',
      mime: 'application/octet-stream',
      size: size,
      at: 0,
    );

    test('reassembles chunks in order', () {
      final a = GhostFileAssembler();
      expect(a.begin(header(5)), isTrue);
      expect(a.add(Uint8List.fromList([1, 2, 3])), isA<GhostFileProgress>());
      final done = a.add(Uint8List.fromList([4, 5]));
      expect(done, isA<GhostReceivedFile>());
      expect((done! as GhostReceivedFile).bytes, [1, 2, 3, 4, 5]);
      expect(a.current, isNull);
    });

    test('drops a chunk nobody announced', () {
      expect(GhostFileAssembler().add(Uint8List(4)), isNull);
    });

    test('an overlong file is dropped, not truncated', () {
      final a = GhostFileAssembler();
      a.begin(header(3));
      expect(a.add(Uint8List(4)), isNull);
      expect(a.current, isNull);
    });

    test('session budget refuses more than it may hold', () {
      final a = GhostFileAssembler(sessionBudgetBytes: 10);
      expect(a.begin(header(6)), isTrue);
      a.add(Uint8List(6));
      expect(a.begin(header(6)), isFalse);
      expect(a.add(Uint8List(6)), isNull);
    });
  });
}
