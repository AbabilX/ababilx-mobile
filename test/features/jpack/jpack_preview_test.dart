import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/jpack/data/jpack_payload.dart';
import 'package:ababilx/features/jpack/data/jpack_preview.dart';

void main() {
  const payload = JPackPayload(
    id: '0b7e1c52-6d7a-4a51-9a5e-2f1c9d3e8b10',
    coverId: 'eid',
    message: 'Eid Mubarak! Warm wishes to you',
    lang: 'en',
  );
  final body = encodeJPackBody(payload);

  test('whole body shows the message', () {
    expect(
      jpackPreviewText(body),
      '💌 JPack · Eid Mubarak! Warm wishes to you',
    );
  });

  test('body cut at 120 chars still reads as a JPack', () {
    final cut = body.substring(0, 120);
    final line = jpackPreviewText(cut)!;
    expect(line, startsWith('💌 JPack'));
    expect(line, isNot(contains('{')));
  });

  test('cut before the message shows the label alone', () {
    expect(jpackPreviewText(body.substring(0, 40)), '💌 JPack');
  });

  test('ordinary messages are left alone', () {
    expect(
      jpackPreviewText(
        '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"hi"}]}]}',
      ),
      isNull,
    );
  });
}
