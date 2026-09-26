import 'dart:io';

import 'package:ababilx/core/theme/theme_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bengali text in the app is drawn by the fallback family, never by Lato.
/// A family name that pubspec does not declare fails silently: the engine
/// falls through to the system font and nothing reports it.
///
/// Bengali code points only: a space or comma is Lato's in the app and the
/// test font's here, which would measure the wrong thing.
const _bengali = 'আমিবাংলায়কথাবলি।ক্ষমাস্ত্রীরাষ্ট্র৳১২৩';

double _width(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: _bengali, style: style.copyWith(fontSize: 20)),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every fallback family is declared in pubspec with files on disk', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in AppFonts.fallback) {
      final block = RegExp(
        r'- family: ' + family + r'\n((?:\s{6,}.*\n)+)',
      ).firstMatch(pubspec);
      expect(block, isNotNull, reason: '$family is not declared in pubspec');
      final assets = RegExp(r'asset: (\S+)').allMatches(block!.group(1)!);
      expect(assets, isNotEmpty);
      for (final asset in assets) {
        expect(
          File(asset.group(1)!).existsSync(),
          isTrue,
          reason: '${asset.group(1)} is missing',
        );
      }
    }
  });

  test('Bengali in the app text theme is drawn by Noto Sans Bengali', () async {
    final loader = FontLoader('NotoSansBengali')
      ..addFont(
        rootBundle.load(
          'assets/fonts/noto_sans_bengali/NotoSansBengali-Regular.ttf',
        ),
      );
    await loader.load();

    final theme = buildAppTextTheme(
      const ColorScheme.light(),
      Typography.material2021().black,
    );
    final app = _width(theme.bodyLarge!);
    final noto = _width(const TextStyle(fontFamily: 'NotoSansBengali'));
    final unresolved = _width(const TextStyle(fontFamily: 'NoSuchFont'));

    expect(app, closeTo(noto, 0.01));
    expect(
      unresolved,
      isNot(closeTo(noto, 0.01)),
      reason: 'the check cannot tell Noto Sans Bengali from the default font',
    );
  });
}
