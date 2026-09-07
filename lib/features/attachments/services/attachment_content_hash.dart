import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Above this a hash moves to a background isolate.
///
/// SHA-256 runs at roughly 5-20 MB/s on a mid-range phone, so a 200 MB video
/// adopted straight after a send would block the UI isolate for seconds — the
/// composer frozen with the message already on screen. Below the threshold the
/// hash is faster than spawning an isolate to do it, so small pictures stay
/// inline and pay nothing.
const int _offloadBytes = 1 << 20;

/// sha256 of a file's bytes, streamed in chunks so fingerprinting a large
/// video never holds the whole thing in memory.
///
/// Hashes whatever is on disk after [AttachmentCipher.decode] — today that is
/// always the plaintext, since the only cipher in use is a passthrough.
Future<String> hashFileContents(File file) async {
  final length = await _lengthOf(file);
  if (length >= _offloadBytes) {
    return compute(hashFileAtPath, file.path, debugLabel: 'hashFileContents');
  }
  return hashFileAtPath(file.path);
}

/// The isolate entry point. Takes a path, not a [File]: an isolate message has
/// to be something the sender can hand over, and a path is.
Future<String> hashFileAtPath(String path) async {
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  await for (final chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  return sink.digest.toString();
}

/// A file that has gone hashes inline, where [hashFileAtPath] raises the same
/// error it always did — rather than paying for an isolate to raise it.
Future<int> _lengthOf(File file) async {
  try {
    return await file.length();
  } catch (_) {
    return 0;
  }
}

/// `Hash.startChunkedConversion` wants a `Sink<Digest>`; `package:crypto`
/// keeps its own under `src/`, so this is the smallest public equivalent.
class _DigestSink implements Sink<Digest> {
  late final Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
