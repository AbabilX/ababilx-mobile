import 'package:ababilx/features/messages/tiptap_autolink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectAutolinks', () {
    test('finds http(s) URLs and strips trailing punctuation', () {
      final hits = detectAutolinks('see https://ababilx.com.');
      expect(hits, hasLength(1));
      expect(hits.single.kind, AutolinkKind.url);
      expect(hits.single.text, 'https://ababilx.com');
      expect(hits.single.href, 'https://ababilx.com');
    });

    test('promotes www. to https', () {
      final hits = detectAutolinks('www.ababilx.com/app');
      expect(hits.single.href, 'https://www.ababilx.com/app');
    });

    test('finds emails', () {
      final hits = detectAutolinks('write murad@ababilx.com please');
      expect(hits.single.kind, AutolinkKind.email);
      expect(hits.single.text, 'murad@ababilx.com');
      expect(hits.single.href, 'mailto:murad@ababilx.com');
    });

    test('finds BD local mobiles and +880 numbers', () {
      final local = detectAutolinks('কল 01712345678');
      expect(local.single.kind, AutolinkKind.phone);
      expect(local.single.href, 'tel:01712345678');

      final intl = detectAutolinks('call +8801712345678');
      expect(intl.single.href, 'tel:+8801712345678');
    });

    test('finds a formatted number, ignores a year', () {
      expect(detectAutolinks('meet 2026-09-08'), isEmpty);
      final hits = detectAutolinks('office (017) 1234-5678');
      expect(hits.single.kind, AutolinkKind.phone);
    });

    test('does not treat a short digit run as a phone', () {
      expect(detectAutolinks('room 12345'), isEmpty);
      expect(detectAutolinks('order 1234567890'), isEmpty);
    });

    test('a URL wins over a phone sitting in its path', () {
      final hits = detectAutolinks('https://ababilx.com/01712345678');
      expect(hits, hasLength(1));
      expect(hits.single.kind, AutolinkKind.url);
    });

    test('splits mixed url, email and phone', () {
      final hits = detectAutolinks(
        'https://ababilx.com murad@ababilx.com 01712345678',
      );
      expect(hits.map((h) => h.kind), [
        AutolinkKind.url,
        AutolinkKind.email,
        AutolinkKind.phone,
      ]);
    });
  });
}
