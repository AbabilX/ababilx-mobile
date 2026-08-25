/// The seam asset encryption will drop into.
///
/// The downloader pipes the network stream through [AttachmentCipher.decode]
/// on its way to the file sink — one line, one place. Adding real encryption
/// later means binding a different implementation in
/// `attachmentCipherProvider`; the downloader, the queue, the authority and
/// every renderer stay exactly as they are.
abstract interface class AttachmentCipher {
  /// False for a cipher whose plaintext cannot be produced from a partial
  /// stream. The downloader reads this and refuses to resume, restarting from
  /// zero instead — so the resume path never has to be rewritten to
  /// accommodate a new mode.
  bool get supportsResume;

  /// [fromOffset] is the ciphertext byte the stream starts at, so a
  /// block-aligned cipher can seek its keystream on a resumed transfer.
  Stream<List<int>> decode(
    Stream<List<int>> cipherStream,
    AttachmentKeyMaterial? key, {
    int fromOffset = 0,
  });
}

/// A pointer into the E2EE vault plus the algorithm the object was sealed
/// with. Never a raw key — the vault stays the only thing that holds those.
class AttachmentKeyMaterial {
  const AttachmentKeyMaterial({required this.algo, required this.keyRef});

  final String algo;
  final String keyRef;
}

/// Today's binding: attachments are stored in the clear on R2, so decoding is
/// the identity transform.
class PassthroughAttachmentCipher implements AttachmentCipher {
  const PassthroughAttachmentCipher();

  @override
  bool get supportsResume => true;

  @override
  Stream<List<int>> decode(
    Stream<List<int>> cipherStream,
    AttachmentKeyMaterial? key, {
    int fromOffset = 0,
  }) => cipherStream;
}
