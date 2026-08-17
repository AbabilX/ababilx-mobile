import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/prime256v1.dart';

/// Pure-Dart ECDH P-256, byte-compatible with the web client's WebCrypto
/// (`ECDH` / `P-256`, `deriveBits(256)` = the raw X coordinate).
///
/// The platform-backed `Ecdh.p256` from `cryptography_flutter` cannot be used
/// here: its Android bridge rebuilds the scalars with `BigInteger(byte[])`,
/// which is *signed* two's-complement, so any `d`, `x` or `y` whose first byte
/// is >= 0x80 becomes a negative number and the agreement either throws or
/// returns a secret the web client never derives. That is roughly seven of
/// every eight identities — the symptom is every DM failing to decrypt and
/// every send erroring out. Everything below treats bytes as unsigned and
/// emits fixed 32-byte, big-endian coordinates, matching JWK/WebCrypto.
class P256KeyPair {
  const P256KeyPair({required this.d, required this.x, required this.y});

  /// Private scalar, 32 bytes big-endian.
  final Uint8List d;

  /// Public point X, 32 bytes big-endian.
  final Uint8List x;

  /// Public point Y, 32 bytes big-endian.
  final Uint8List y;
}

class P256Ecdh {
  P256Ecdh._();

  static const coordinateLength = 32;
  static final _domain = ECCurve_prime256v1();
  static final _random = Random.secure();

  static P256KeyPair newKeyPair() {
    final n = _domain.n;
    BigInt d;
    do {
      d = _randomBigInt();
    } while (d < BigInt.one || d >= n);
    final point = (_domain.G * d)!;
    return P256KeyPair(
      d: encodeCoordinate(d),
      x: encodeCoordinate(point.x!.toBigInteger()!),
      y: encodeCoordinate(point.y!.toBigInteger()!),
    );
  }

  /// The shared secret the web client sees: the X coordinate of `d * remote`,
  /// left-padded to 32 bytes (WebCrypto never trims it, so neither do we).
  static Uint8List sharedSecretX({
    required List<int> privateD,
    required List<int> remoteX,
    required List<int> remoteY,
  }) {
    final d = decodeCoordinate(privateD);
    if (d < BigInt.one || d >= _domain.n) {
      throw ArgumentError('Invalid P-256 private scalar');
    }
    final remote = _publicPoint(decodeCoordinate(remoteX), decodeCoordinate(remoteY));
    final product = remote * d;
    if (product == null || product.isInfinity) {
      throw ArgumentError('Invalid P-256 shared secret');
    }
    return encodeCoordinate(product.x!.toBigInteger()!);
  }

  /// Rejects points off the curve or at infinity before they reach the scalar
  /// multiply — an attacker-supplied public key must never leak the private key
  /// through an invalid-curve point.
  static ECPoint _publicPoint(BigInt x, BigInt y) {
    final curve = _domain.curve;
    final left = curve.fromBigInteger(y).square();
    final fx = curve.fromBigInteger(x);
    final right = fx.square() * fx + curve.a! * fx + curve.b!;
    if (left.toBigInteger() != right.toBigInteger()) {
      throw ArgumentError('Public key is not on the P-256 curve');
    }
    final point = curve.createPoint(x, y);
    if (point.isInfinity) throw ArgumentError('Public key is the point at infinity');
    return point;
  }

  /// 32-byte big-endian, unsigned — the JWK / WebCrypto wire form.
  static Uint8List encodeCoordinate(BigInt value) {
    final out = Uint8List(coordinateLength);
    var rest = value;
    final mask = BigInt.from(0xff);
    for (var i = coordinateLength - 1; i >= 0; i--) {
      out[i] = (rest & mask).toInt();
      rest = rest >> 8;
    }
    if (rest != BigInt.zero) {
      throw ArgumentError('P-256 coordinate does not fit in 32 bytes');
    }
    return out;
  }

  /// Unsigned big-endian decode. Accepts short input (a peer that stripped
  /// leading zero bytes) but never reads a high bit as a sign bit.
  static BigInt decodeCoordinate(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > coordinateLength) {
      throw ArgumentError('Invalid P-256 coordinate length: ${bytes.length}');
    }
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte & 0xff);
    }
    return value;
  }

  static BigInt _randomBigInt() {
    var value = BigInt.zero;
    for (var i = 0; i < coordinateLength; i++) {
      value = (value << 8) | BigInt.from(_random.nextInt(256));
    }
    return value;
  }
}
