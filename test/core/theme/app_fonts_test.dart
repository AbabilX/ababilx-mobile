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
        expect(File(asset.group(1)!).existsSync(), isTrue,
            reason: '${asset.group(1)} is missing');
      }
    }
  });

  test('Bengali in the app text theme is drawn by Shohid Abu Sayed', () async {
    final loader = FontLoader('ShohidAbuSayed')
      ..addFont(rootBundle.load('assets/fonts/shohid_abu_sayed/LiShohidAbuSayedUnicode.ttf'));
    await loader.load();

    final theme = buildAppTextTheme(
      const ColorScheme.light(),
      Typography.material2021().black,
    );
    final app = _width(theme.bodyLarge!);
    final sayed = _width(const TextStyle(fontFamily: 'ShohidAbuSayed'));
    final unresolved = _width(const TextStyle(fontFamily: 'NoSuchFont'));

    expect(app, closeTo(sayed, 0.01));
    expect(unresolved, isNot(closeTo(sayed, 0.01)),
        reason: 'the check cannot tell Shohid Abu Sayed from the default font');
  });
}
