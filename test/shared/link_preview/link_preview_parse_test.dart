import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/shared/link-preview/link_preview_parse.dart';

void main() {
  group('parseLinkPreview', () {
    test('reads the Open Graph block', () {
      final preview = parseLinkPreview('https://ababilx.com/post', '''
        <html><head>
        <meta property="og:title" content="A title">
        <meta property="og:description" content="What it says">
        <meta property="og:image" content="https://cdn.ababilx.com/a.png">
        <meta property="og:site_name" content="AbabilX">
        </head></html>
      ''');
      expect(preview.title, 'A title');
      expect(preview.description, 'What it says');
      expect(preview.imageUrl, 'https://cdn.ababilx.com/a.png');
      expect(preview.siteName, 'AbabilX');
      expect(preview.isEmpty, isFalse);
    });

    test('falls back to <title> and then to the favicon', () {
      final preview = parseLinkPreview('https://ababilx.com/x/y', '''
        <head><title>Just a title</title>
        <link rel="shortcut icon" href="/favicon.ico"></head>
      ''');
      expect(preview.title, 'Just a title');
      // The reference app folds the favicon into the image slot, and a small
      // square is exactly what the 72dp thumbnail wants.
      expect(preview.imageUrl, 'https://ababilx.com/favicon.ico');
    });

    test(
      'takes single-quoted markup, which the reference parser drops on the floor',
      () {
        final preview = parseLinkPreview(
          'https://ababilx.com',
          "<meta property='og:title' content='Single quoted'>",
        );
        expect(preview.title, 'Single quoted');
      },
    );

    test('the first tag of a repeated property wins', () {
      final preview = parseLinkPreview('https://ababilx.com', '''
        <meta property="og:title" content="First">
        <meta property="og:title" content="Second">
      ''');
      expect(preview.title, 'First');
    });

    test('decodes entities twice, as the reference parser does', () {
      // Plenty of pages emit an already-encoded string into a meta tag.
      final preview = parseLinkPreview(
        'https://ababilx.com',
        '<meta property="og:title" content="Tom &amp;amp; Jerry &#x1F600;">',
      );
      expect(preview.title, 'Tom & Jerry 😀');
    });

    test('refuses a non-http image scheme', () {
      final preview = parseLinkPreview(
        'https://ababilx.com',
        '<meta property="og:title" content="T">'
            '<meta property="og:image" content="javascript:alert(1)">',
      );
      expect(preview.imageUrl, isNull);
    });

    test('a page with nothing to say is empty, not an error', () {
      final preview = parseLinkPreview('https://ababilx.com', '<html></html>');
      expect(preview.isEmpty, isTrue);
    });

    test('collapses whitespace and caps a runaway description', () {
      final long = 'x' * 900;
      final preview = parseLinkPreview('https://ababilx.com', '''
        <meta property="og:title" content="a
        b">
        <meta property="og:description" content="$long">
      ''');
      expect(preview.title, 'a b');
      expect(preview.description!.length, lessThan(700));
    });
  });
}
