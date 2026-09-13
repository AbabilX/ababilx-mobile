import 'package:ababilx/features/messages/message_e2ee/recovery_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// The recovery derivation has to be byte-identical to the web client, or a
/// code written down on this phone opens nothing in a browser and the user has
/// lost their history with no error to point at.
///
/// The vector is fixed so both sides assert the same number:
///   HKDF-SHA256(ikm = 00..1f, salt = ff..e0, info = "ababilx-recovery-key-v1")
/// The web twin is src/lib/chat-e2ee/recovery-key.test.mjs.
const _expected =
    '74ba6507bcb58eae71adb8b463381c90e18bd461e3f780716225dd89c3fff83f';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('derivation matches the cross-platform vector', () async {
    final ikm = List<int>.generate(32, (i) => i);
    final salt = List<int>.generate(32, (i) => 255 - i);
    final key = await RecoveryKey.deriveKey(ikm, salt);
    expect(_hex(await key.extractBytes()), _expected);
  });

  test('a different salt derives a different key', () async {
    final ikm = List<int>.generate(32, (i) => i);
    final key = await RecoveryKey.deriveKey(ikm, List<int>.filled(32, 1));
    expect(_hex(await key.extractBytes()), isNot(_expected));
  });

  test('format and parse round trip, ignoring spacing and case', () {
    final code = RecoveryKey.generateCode();
    final shown = RecoveryKey.format(code);
    expect(shown.length, 64 + 15); // 64 hex digits, 15 separators
    expect(RecoveryKey.parse(shown), code);
    expect(RecoveryKey.parse(shown.toLowerCase().replaceAll('-', ' ')), code);
  });

  test('an incomplete code is rejected rather than padded', () {
    expect(RecoveryKey.parse('A1B2-C3D4'), isNull);
    expect(RecoveryKey.parse(''), isNull);
  });

  test('wrap then unwrap returns the same identity', () async {
    final code = RecoveryKey.generateCode();
    final jwk = {'kty': 'EC', 'crv': 'P-256', 'd': 'abc', 'x': 'x', 'y': 'y'};
    final vault = await RecoveryKey.wrap(jwk, code);
    expect(await RecoveryKey.unwrap(vault, code), jwk);
  });

  test('the wrong code does not open the vault', () async {
    final vault = await RecoveryKey.wrap({
      'd': 'secret',
    }, RecoveryKey.generateCode());
    await expectLater(
      RecoveryKey.unwrap(vault, RecoveryKey.generateCode()),
      throwsA(isA<Object>()),
    );
  });
}
