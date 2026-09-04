import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/message_e2ee/device_link_approval.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';

void main() {
  group('device link payload', () {
    test('pulls the token and ephemeral key out of a scanned QR', () {
      final request = parseDeviceLinkPayload(
        'ababilx://link-messages?t=abc123&k=eyJrdHkiOiJFQyJ9',
      );
      expect(request, isNotNull);
      expect(request!.token, 'abc123');
      expect(request.publicKeyParam, 'eyJrdHkiOiJFQyJ9');
    });

    test('survives surrounding whitespace from the scanner', () {
      final request = parseDeviceLinkPayload(
        '  ababilx://link-messages?t=abc123&k=zzz\n',
      );
      expect(request?.token, 'abc123');
      expect(request?.publicKeyParam, 'zzz');
    });

    test('a sign-in QR is not a device link', () {
      const login = 'ababilx://desktop-login?t=abc123';
      expect(isDeviceLinkPayload(login), isFalse);
      expect(parseDeviceLinkPayload(login), isNull);
    });

    // Without the ephemeral key there is nothing to seal the identity against,
    // so a truncated payload has to be refused rather than half-processed.
    test('a link with no ephemeral key is refused', () {
      expect(
        parseDeviceLinkPayload('ababilx://link-messages?t=abc123'),
        isNull,
      );
      expect(
        parseDeviceLinkPayload('ababilx://link-messages?t=&k=zzz'),
        isNull,
      );
    });
  });

  group('link verification code', () {
    late MessageVault vault;

    setUp(() {
      const storage = SecureStorage(FlutterSecureStorage());
      vault = MessageVault(ChatRepository(ApiClient(storage)), storage);
    });

    // The code only means anything if both screens compute the same six digits.
    // These constants are the cross-platform contract: the web client derives
    // them in `lib/chat-e2ee/device-link.ts` as the first three bytes of
    // SHA-256("<crv>.<x>.<y>") modulo 1e6. Changing either side alone silently
    // turns the check into two unrelated numbers that never match.
    test('matches the web derivation', () async {
      expect(
        await vault.linkVerificationCode({
          'crv': 'P-256',
          'x': 'abc',
          'y': 'def',
        }),
        '443144',
      );
      expect(
        await vault.linkVerificationCode({
          'crv': 'P-256',
          'x': 'AQIDBA',
          'y': 'BQYHCA',
        }),
        '553966',
      );
    });

    test('is always six digits, zero-padded', () async {
      for (var i = 0; i < 40; i++) {
        final code = await vault.linkVerificationCode({
          'crv': 'P-256',
          'x': 'x$i',
          'y': 'y$i',
        });
        expect(code, hasLength(6));
        expect(RegExp(r'^\d{6}$').hasMatch(code), isTrue);
      }
    });

    test('a different key gives a different code', () async {
      final a = await vault.linkVerificationCode({
        'crv': 'P-256',
        'x': 'abc',
        'y': 'def',
      });
      final b = await vault.linkVerificationCode({
        'crv': 'P-256',
        'x': 'abc',
        'y': 'deg',
      });
      expect(a, isNot(b));
    });

    test('the ephemeral key survives the QR round trip', () {
      final ephemeral = vault.newLinkEphemeral();
      final decoded = vault.decodeLinkPublicKey(
        vault.encodeLinkPublicKey(ephemeral),
      );
      expect(decoded['crv'], 'P-256');
      expect(decoded['x'], isNotEmpty);
      expect(decoded['y'], isNotEmpty);
      // The public half only. Shipping 'd' in the QR would put the private key
      // on screen for any camera in the room.
      expect(decoded.containsKey('d'), isFalse);
    });
  });
}
