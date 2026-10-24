import 'package:ababilx/shared/widgets/themed_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ink, accent and white follow the theme; skin stays', () {
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );
    const raw =
        '<path fill="#090814"/><path fill="#000000"/><path fill="#fff"/><path fill="#ffb7b7"/>';
    final out = themedSvg(raw, dark);
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    expect(out, contains('fill="${hex(dark.onSurface)}"'));
    expect(out, contains('fill="${hex(dark.primary)}"'));
    expect(out, contains('fill="${hex(dark.surface)}"'));
    expect(out, contains('fill="#ffb7b7"'));
    expect(out, isNot(contains('#090814')));
  });

  testWidgets('the transfer picture loads and draws', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ThemedIllustration('assets/images/transfer_chats.svg'),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
