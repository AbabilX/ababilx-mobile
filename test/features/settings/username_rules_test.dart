import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat-people/user_qr_payload.dart';
import 'package:ababilx/features/settings/username/username_rules.dart';

void main() {
  group('normalizeUsername', () {
    test('drops the @ people type and folds case', () {
      expect(normalizeUsername('@MuRaD'), 'murad');
      expect(normalizeUsername('  Murad_99  '), 'murad_99');
    });
  });

  group('usernameError', () {
    test('accepts the shapes the server accepts', () {
      for (final ok in ['murad', 'murad.khan', 'murad-khan', 'a1b', '@Murad']) {
        expect(usernameError(ok), isNull, reason: ok);
        expect(isValidUsername(ok), isTrue, reason: ok);
      }
    });

    test('nothing typed yet is not an error', () {
      expect(usernameError(''), isNull);
      expect(isValidUsername(''), isFalse);
    });

    test('refuses what the server refuses', () {
      expect(usernameError('ab'), isNotNull); // too short
      expect(usernameError('a' * 33), isNotNull); // too long
      expect(usernameError('_murad'), isNotNull); // leading separator
      expect(usernameError('murad.'), isNotNull); // trailing separator
      expect(usernameError('murad..khan'), isNotNull); // doubled separator
      expect(usernameError('murad khan'), isNotNull); // space
      expect(usernameError('murаd'), isNotNull); // Cyrillic lookalike
      expect(usernameError('support'), isNotNull); // reserved
    });
  });

  group('user QR payload', () {
    test('round-trips a handle', () {
      final payload = buildUserQrPayload('@Murad');
      expect(payload, 'ababilx://user?u=murad');
      expect(usernameFromQrPayload(payload), 'murad');
    });

    test('accepts a bare @handle, which is what a poster would carry', () {
      expect(usernameFromQrPayload('@murad.khan'), 'murad.khan');
    });

    test('ignores every other code', () {
      // A sign-in code and a device-link code go to their own handlers; plain
      // text and foreign links must not look like a contact.
      expect(usernameFromQrPayload('ababilx://desktop-login?t=abc'), isNull);
      expect(usernameFromQrPayload('ababilx://link-messages?t=a&k=b'), isNull);
      expect(usernameFromQrPayload('https://example.com/murad'), isNull);
      expect(usernameFromQrPayload('murad'), isNull);
      expect(usernameFromQrPayload(''), isNull);
    });

    test('a shared link carries the same handle', () {
      final link = buildUserLink('@Murad');
      expect(link, 'https://www.ababilx.com/u/murad');
      expect(usernameFromQrPayload(link), 'murad');
      expect(
        usernameFromQrPayload('https://ababilx.com/u/murad.khan'),
        'murad.khan',
      );
    });

    test('only our own /u/ link is a handle', () {
      expect(usernameFromQrPayload('http://www.ababilx.com/u/murad'), isNull);
      expect(usernameFromQrPayload('https://evil.com/u/murad'), isNull);
      expect(
        usernameFromQrPayload('https://www.ababilx.com/u/murad/x'),
        isNull,
      );
      expect(
        usernameFromQrPayload('https://www.ababilx.com/privacy-policy'),
        isNull,
      );
      expect(
        usernameFromQrPayload('https://www.ababilx.com/u/support'),
        isNull,
      );
    });

    test('a malformed handle inside a code is not a handle', () {
      expect(usernameFromQrPayload('ababilx://user?u=@@'), isNull);
      expect(usernameFromQrPayload('ababilx://user?u=support'), isNull);
      expect(usernameFromQrPayload('ababilx://user'), isNull);
    });
  });
}
