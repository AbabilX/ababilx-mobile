import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../message_e2ee/p256_ecdh.dart';
import 'history_transfer_codec.dart';

/// The crypto of a phone → new device history transfer.
///
/// One random 256-bit key per transfer, sealed to the ephemeral public key the
/// destination drew into its QR — read off the CAMERA, never fetched from the
/// server, which is the whole reason the relay can hold a user's history
/// without being able to read a byte of it.
///
/// **Every string here is part of the wire format.** Desktop and web must
/// derive byte-identically, so a change on one side alone produces chunks the
/// other cannot open, with no error naming the cause. `history_transfer_test`
/// pins the derivation against a fixed vector for exactly that reason.
class HistoryTransferCrypto {
  HistoryTransferCrypto._();

  /// Bumped only for a change an older reader could not survive.
  static const int formatVersion = 1;

  static const _envelopeAad = 'ababilx-history-transfer-envelope-v1';
  static const _chunkAad = 'ababilx-history-transfer-chunk-v1';
  static const _manifestAad = 'ababilx-history-transfer-manifest-v1';
  static const _nonceBytes = 12;

  static final _aes = AesGcm.with256bits();

  /// A fresh key for this transfer alone.
  ///
  /// Deliberately NOT derived from the account identity the way an archive key
  /// is: an archive is read back by the same account later, while a transfer is
  /// handed to one device once. A per-transfer key means a leaked envelope
  /// exposes that transfer and nothing else, and the relay never holds bytes
  /// sealed under a key that outlives it.
  static Uint8List newTransferKey() => HistoryTransferCodec.randomBytes(32);

  /// Seals the transfer key for the scanned device.
  ///
  /// The wrapping key is SHA-256 over the raw ECDH X coordinate — the same
  /// derivation the device-link envelope uses, so web and desktop already have
  /// this code path. Only the AAD differs, which is what keeps a link envelope
  /// and a transfer envelope from being interchangeable.
  static Future<Map<String, dynamic>> sealTransferKey({
    required List<int> transferKey,
    required Map<String, dynamic> destinationJwk,
  }) async {
    final ephemeral = P256Ecdh.newKeyPair();
    final nonce = HistoryTransferCodec.randomBytes(_nonceBytes);
    final wrapping = await _agreedKey(ephemeral, destinationJwk);
    final box = await _aes.encrypt(
      transferKey,
      secretKey: wrapping,
      nonce: nonce,
      aad: utf8.encode(_envelopeAad),
    );
    return {
      'v': formatVersion,
      'ephemeral_public_key': HistoryTransferCodec.publicJwk(ephemeral),
      'nonce': HistoryTransferCodec.b64(nonce),
      'ciphertext': HistoryTransferCodec.b64([
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
    };
  }

  /// Opens an envelope with the ephemeral private key. Only the destination
  /// runs this; it lives here so both halves of the format stay in one file
  /// and the test can prove they round-trip.
  static Future<Uint8List> openTransferKey({
    required Map<String, dynamic> envelope,
    required P256KeyPair ephemeral,
  }) async {
    final wrapping = await _agreedKey(
      ephemeral,
      Map<String, dynamic>.from(envelope['ephemeral_public_key'] as Map),
    );
    final clear = await _aes.decrypt(
      _secretBox(envelope['ciphertext'] as String, envelope['nonce'] as String),
      secretKey: wrapping,
      aad: utf8.encode(_envelopeAad),
    );
    return Uint8List.fromList(clear);
  }

  /// Seals one chunk, binding its INDEX into the AAD.
  ///
  /// Without that binding the relay is a bag of independently valid chunks:
  /// dropping the last one or swapping two would still verify, and the
  /// destination would import a shorter, entirely plausible history.
  static Future<Uint8List> sealChunk({
    required List<int> transferKey,
    required int index,
    required List<int> plaintext,
  }) => _seal(transferKey, chunkAad(index), plaintext);

  static Future<Uint8List> openChunk({
    required List<int> transferKey,
    required int index,
    required List<int> sealed,
  }) => _open(transferKey, chunkAad(index), sealed);

  /// The manifest is sealed under its own AAD so a chunk can never be replayed
  /// into the manifest slot, or the other way round.
  static Future<Uint8List> sealManifest({
    required List<int> transferKey,
    required List<int> plaintext,
  }) => _seal(transferKey, utf8.encode(_manifestAad), plaintext);

  static Future<Uint8List> openManifest({
    required List<int> transferKey,
    required List<int> sealed,
  }) => _open(transferKey, utf8.encode(_manifestAad), sealed);

  /// Exposed so the cross-platform test can pin it: a change here makes every
  /// chunk unopenable on the other side, silently.
  static List<int> chunkAad(int index) => utf8.encode('$_chunkAad:$index');

  /// Sealed bytes are `nonce || ciphertext || tag`. The reader splits on a
  /// fixed 12 bytes, so this layout is part of the format.
  static Future<Uint8List> _seal(
    List<int> key,
    List<int> aad,
    List<int> plaintext,
  ) async {
    final nonce = HistoryTransferCodec.randomBytes(_nonceBytes);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> _open(
    List<int> key,
    List<int> aad,
    List<int> sealed,
  ) async {
    if (sealed.length < _nonceBytes + 16) {
      throw ArgumentError('sealed payload is too short to be ours');
    }
    final bytes = Uint8List.fromList(sealed);
    final clear = await _aes.decrypt(
      SecretBox(
        bytes.sublist(_nonceBytes, bytes.length - 16),
        nonce: bytes.sublist(0, _nonceBytes),
        mac: Mac(bytes.sublist(bytes.length - 16)),
      ),
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(clear);
  }

  static Future<SecretKey> _agreedKey(
    P256KeyPair private,
    Map<String, dynamic> remote,
  ) async {
    final shared = P256Ecdh.sharedSecretX(
      privateD: private.d,
      remoteX: HistoryTransferCodec.bytesFromB64(remote['x'] as String),
      remoteY: HistoryTransferCodec.bytesFromB64(remote['y'] as String),
    );
    return SecretKey((await Sha256().hash(shared)).bytes);
  }

  static SecretBox _secretBox(String ciphertext, String nonce) {
    final all = HistoryTransferCodec.bytesFromB64(ciphertext);
    return SecretBox(
      all.sublist(0, all.length - 16),
      nonce: HistoryTransferCodec.bytesFromB64(nonce),
      mac: Mac(all.sublist(all.length - 16)),
    );
  }
}
