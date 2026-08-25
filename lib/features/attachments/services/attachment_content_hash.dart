import 'dart:io';

import 'package:crypto/crypto.dart';

/// sha256 of a file's bytes, streamed in chunks so fingerprinting a large
/// video never holds the whole thing in memory.
///
/// Hashes whatever is on disk after [AttachmentCipher.decode] — today that is
/// always the plaintext, since the only cipher in use is a passthrough.
Future<String> hashFileContents(File file) async {
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  await for (final chunk in file.openRead()) {
    input.add(chunk);
  }
  input.close();
  return sink.digest.toString();
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
