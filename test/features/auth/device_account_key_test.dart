import 'package:ababilx/features/auth/device/device_account_key.dart';
import 'package:flutter_test/flutter_test.dart';

// Pinned against ababilx-server handlers/auth/device/wire_test.go. Change one
// side alone and every key-only account's sign-in fails.
const _publicKey = 'A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg';
const _nonce = 'oKGio6SlpqeoqaqrrK2ur6ChoqOkpaanqKmqq6ytrq8';
const _signature =
    'c0aea4491216c20b5d749029001d8126292174e021dc38f1893e38074d2ffa880ccbf0aebdec7cae9b9ba9107ef3189c6ec9db8bcd447ce7d480a5dec3a5340c';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('same key and signature as the server vector', () async {
    final key = await DeviceAccountKey.fromSeed(
      List<int>.generate(32, (i) => i),
    );
    expect(key.encodedPublicKey, _publicKey);
    final signature = await key.sign(
      'register',
      DeviceAccountKey.decodeBytes(_nonce),
    );
    expect(_hex(signature), _signature);
  });

  test('stored seed round-trips; garbage reads as no key', () async {
    final key = await DeviceAccountKey.generate();
    final again = await DeviceAccountKey.decode(key.encodedSeed);
    expect(again?.encodedPublicKey, key.encodedPublicKey);
    expect(await DeviceAccountKey.decode(null), isNull);
    expect(await DeviceAccountKey.decode('not-a-seed'), isNull);
  });

  test('purpose is part of what is signed', () async {
    final key = await DeviceAccountKey.fromSeed(List<int>.filled(32, 7));
    final nonce = List<int>.filled(32, 1);
    expect(
      await key.sign('register', nonce),
      isNot(await key.sign('login', nonce)),
    );
  });
}
