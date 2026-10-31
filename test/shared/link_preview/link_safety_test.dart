import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/shared/link-preview/link_safety.dart';

void main() {
  group('isValidPreviewUrl', () {
    test('accepts an ordinary https link', () {
      expect(isValidPreviewUrl('https://ababilx.com/blog/post'), isTrue);
      expect(isValidPreviewUrl('https://youtu.be/RsZMEr-AECc?si=abc'), isTrue);
    });

    test('refuses anything that is not https', () {
      expect(isValidPreviewUrl('http://ababilx.com'), isFalse);
      expect(isValidPreviewUrl('ftp://ababilx.com'), isFalse);
      expect(isValidPreviewUrl(null), isFalse);
      expect(isValidPreviewUrl(''), isFalse);
    });

    test('refuses a mixed-script domain', () {
      // Cyrillic а. Left alone it would draw a card carrying Apple's real
      // title and logo, which is a better lure than the bare link.
      expect(isValidPreviewUrl('https://аpple.com'), isFalse);
      // All non-ASCII is fine — that is a real international domain.
      expect(isValidPreviewUrl('https://例え.テスト'), isTrue);
    });

    test('refuses box drawing and bidi overrides anywhere in the URL', () {
      expect(isValidPreviewUrl('https://ababilx.com/\u202Egnp.txt'), isFalse);
      expect(isValidPreviewUrl('https://abab\u2500ilx.com'), isFalse);
    });

    test('refuses doubled periods and an ellipsis in the host', () {
      expect(isValidPreviewUrl('https://ababilx..com'), isFalse);
      expect(isValidPreviewUrl('https://ababilx\u2026com'), isFalse);
    });

    test('refuses the reserved example and darknet domains', () {
      expect(isValidPreviewUrl('https://example.com'), isFalse);
      expect(isValidPreviewUrl('https://deep.example.com'), isFalse);
      expect(isValidPreviewUrl('https://something.onion'), isFalse);
      expect(isValidPreviewUrl('https://localhost'), isFalse);
    });

    test('refuses an address inside this network', () {
      expect(isValidPreviewUrl('https://127.0.0.1/admin'), isFalse);
      expect(isValidPreviewUrl('https://192.168.1.1'), isFalse);
      expect(isValidPreviewUrl('https://10.0.0.5'), isFalse);
      expect(isValidPreviewUrl('https://172.16.4.1'), isFalse);
      // Link-local, and the metadata address most of all.
      expect(isValidPreviewUrl('https://169.254.169.254'), isFalse);
      // Carrier-grade NAT: a phone on mobile data lives inside this range.
      expect(isValidPreviewUrl('https://100.64.0.1'), isFalse);
      expect(isValidPreviewUrl('https://[::1]/'), isFalse);
      expect(isValidPreviewUrl('https://[fd00::1]/'), isFalse);
      // A routable literal is still allowed — the reference app only blocks
      // private ones.
      expect(isValidPreviewUrl('https://8.8.8.8'), isTrue);
    });
  });

  group('previewDomain', () {
    test('drops a leading www', () {
      expect(previewDomain('https://www.youtube.com/watch?v=x'), 'youtube.com');
      expect(previewDomain('https://github.com'), 'github.com');
    });
  });
}
