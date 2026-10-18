import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/messages/history-transfer/live/live_wire.dart';
import 'package:flutter_test/flutter_test.dart';

// Pinned byte for byte by web's src/lib/history/live/wire.test.mjs.
const _getFrameHex =
    '0000002a7b2274223a22676574222c22726571223a372c22636f6e76223a226331222c226c696d6974223a32307d';
const _getPieceHex = '01' '00000003' '0000002e' '00000000' + _getFrameHex;

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('encodes a frame exactly as the web does', () {
    final frame = encodeLiveFrame({'t': 'get', 'req': 7, 'conv': 'c1', 'limit': 20});
    expect(_hex(frame), _getFrameHex);
    expect(livePieces(3, frame).map(_hex).toList(), [_getPieceHex]);
  });

  test('splits at 16 KiB and reassembles interleaved pieces', () {
    final body = Uint8List.fromList(List.generate(40000, (i) => i % 251));
    final a = livePieces(1, encodeLiveFrame({'t': 'file_data', 'req': 1, 'offset': 0}, body)).toList();
    final b = livePieces(2, encodeLiveFrame({'t': 'pong'})).toList();
    expect(a.length, 3);
    expect(a.every((p) => p.length <= livePieceBytes), isTrue);
    final asm = LiveAssembler();
    expect(asm.push(a[0]), isNull);
    expect(decodeLiveFrame(asm.push(b[0])!).type, 'pong');
    expect(asm.push(a[1]), isNull);
    final done = decodeLiveFrame(asm.push(a[2])!);
    expect(done.type, 'file_data');
    expect(done.body, body);
  });

  test('refuses a piece that runs past its frame', () {
    final piece = Uint8List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0xaa, 0xbb]);
    expect(() => LiveAssembler().push(piece), throwsFormatException);
  });

  test('page body is gzip NDJSON', () {
    final body = gzipLines([{'id': 'a'}, {'id': 'b'}]);
    final lines = utf8.decode(gzip.decode(body)).trim().split('\n');
    expect(lines.map((l) => jsonDecode(l)['id']).toList(), ['a', 'b']);
  });
}
