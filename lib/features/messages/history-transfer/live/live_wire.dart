import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Live history data-channel framing — `ababilx-server/docs/history-live-protocol.md`
/// section 2, byte-identical with web's `lib/history/live/wire.ts` (both
/// pinned by the same fixture hex in their tests).
///
/// A frame is `u32be header_len | header JSON | body`, cut into pieces of at
/// most 16 KiB: `u8 1 | u32be frame_id | u32be total | u32be offset | bytes`.
const int livePieceBytes = 16 * 1024;
const int livePieceHead = 13;
const int liveMaxFrame = 8 << 20;

class LiveFrame {
  const LiveFrame(this.header, this.body);

  final Map<String, dynamic> header;
  final Uint8List body;

  String get type => header['t'] as String? ?? '';
}

Uint8List encodeLiveFrame(Map<String, dynamic> header, [List<int>? body]) {
  final head = utf8.encode(jsonEncode(header));
  final rest = body ?? const <int>[];
  final out = Uint8List(4 + head.length + rest.length);
  ByteData.sublistView(out).setUint32(0, head.length);
  out.setRange(4, 4 + head.length, head);
  out.setRange(4 + head.length, out.length, rest);
  return out;
}

LiveFrame decodeLiveFrame(Uint8List bytes) {
  if (bytes.length < 4) throw const FormatException('frame too short');
  final length = ByteData.sublistView(bytes).getUint32(0);
  if (4 + length > bytes.length) throw const FormatException('header too long');
  final header = jsonDecode(utf8.decode(bytes.sublist(4, 4 + length)));
  if (header is! Map || header['t'] is! String) {
    throw const FormatException('frame has no type');
  }
  return LiveFrame(
    Map<String, dynamic>.from(header),
    Uint8List.sublistView(bytes, 4 + length),
  );
}

/// Cuts one encoded frame into channel messages.
Iterable<Uint8List> livePieces(int frameId, Uint8List frame) sync* {
  const room = livePieceBytes - livePieceHead;
  var offset = 0;
  do {
    final end = (offset + room).clamp(0, frame.length);
    final piece = Uint8List(livePieceHead + end - offset);
    final view = ByteData.sublistView(piece);
    piece[0] = 1;
    view.setUint32(1, frameId);
    view.setUint32(5, frame.length);
    view.setUint32(9, offset);
    piece.setRange(livePieceHead, piece.length, frame, offset);
    yield piece;
    offset = end;
  } while (offset < frame.length);
}

/// Reassembles pieces; returns a frame once its last byte arrived.
class LiveAssembler {
  final _open = <int, ({Uint8List bytes, List<int> got})>{};

  Uint8List? push(Uint8List piece) {
    if (piece.length < livePieceHead || piece[0] != 1) {
      throw const FormatException('unknown piece version');
    }
    final view = ByteData.sublistView(piece);
    final id = view.getUint32(1);
    final total = view.getUint32(5);
    final offset = view.getUint32(9);
    final size = piece.length - livePieceHead;
    if (total > liveMaxFrame || offset + size > total) {
      throw const FormatException('piece outside its frame');
    }
    final entry = _open.putIfAbsent(
      id,
      () => (bytes: Uint8List(total), got: [0]),
    );
    entry.bytes.setRange(offset, offset + size, piece, livePieceHead);
    entry.got[0] += size;
    if (entry.got[0] < total) return null;
    _open.remove(id);
    return entry.bytes;
  }

  void clear() => _open.clear();
}

/// gzip NDJSON, one JSON value per line — a `page` frame's body.
Uint8List gzipLines(Iterable<Object?> values) {
  final text = StringBuffer();
  for (final value in values) {
    text
      ..write(jsonEncode(value))
      ..write('\n');
  }
  return Uint8List.fromList(gzip.encode(utf8.encode(text.toString())));
}
