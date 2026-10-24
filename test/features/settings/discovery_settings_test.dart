import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/settings/discovery/discovery_settings.dart';

/// Mirrors `NormalizePhone` in
/// `ababilx-server/services/chat/access_connections.go`. If a case here starts
/// disagreeing with the Go one, the phone field enables Save for a number the
/// server will refuse.
void main() {
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
