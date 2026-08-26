import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/settings/discovery/discovery_settings.dart';

/// Mirrors `NormalizePhone` in
/// `ababilx-server/services/chat/access_connections.go`. If a case here starts
/// disagreeing with the Go one, the phone field enables Save for a number the
/// server will refuse.
void main() {
  group('normalizePhoneNumber', () {
    test('strips the formatting people type', () {
      expect(normalizePhoneNumber('+880 171-234 5678'), '+8801712345678');
      expect(normalizePhoneNumber('  +8801712345678  '), '+8801712345678');
      expect(normalizePhoneNumber('+(880) 1712345678'), '+8801712345678');
    });

    test('rejects a number with no country code', () {
      // The same digits mean different people in different countries, and
      // stored numbers are all E.164.
      expect(normalizePhoneNumber('01712345678'), isNull);
      expect(normalizePhoneNumber('8801712345678'), isNull);
    });

    test('rejects lengths outside phone range', () {
      expect(normalizePhoneNumber('+1234567'), isNull);
      expect(normalizePhoneNumber('+1234567890123456'), isNull);
    });

    test('accepts the boundaries', () {
      expect(normalizePhoneNumber('+12345678'), '+12345678');
      expect(normalizePhoneNumber('+123456789012345'), '+123456789012345');
    });

    test('empty means "no number", which is allowed', () {
      expect(normalizePhoneNumber(''), '');
      expect(normalizePhoneNumber('   '), '');
    });
  });

  group('DiscoverySettings', () {
    test('defaults match the server: username off, email and phone on', () {
      final parsed = DiscoverySettings.fromJson(const {});
      expect(parsed.byUsername, isFalse);
      expect(parsed.byEmail, isTrue);
      expect(parsed.byPhone, isTrue);
      expect(parsed.phoneNumber, '');
    });

    test('reads the API payload', () {
      final parsed = DiscoverySettings.fromJson(const {
        'phone_number': '+8801712345678',
        'discoverable_by_username': true,
        'discoverable_by_email': false,
        'discoverable_by_phone': true,
      });
      expect(parsed.phoneNumber, '+8801712345678');
      expect(parsed.byUsername, isTrue);
      expect(parsed.byEmail, isFalse);
    });
  });
}
