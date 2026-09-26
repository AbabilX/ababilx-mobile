import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/khaam/data/khaam_payload.dart';
import 'package:ababilx/features/khaam/data/khaam_preview.dart';

void main() {
  const payload = KhaamPayload(
    id: '0b7e1c52-6d7a-4a51-9a5e-2f1c9d3e8b10',
    coverId: 'eid',
    message: 'Eid Mubarak! Warm wishes to you',
    lang: 'en',
  );
  final body = encodeKhaamBody(payload);
  bool always(String _) => true;

  test('unopened: the label alone, never the message', () {
    expect(khaamPreviewText(body, lang: 'en'), '💌 Khaam');
    expect(khaamPreviewText(body, lang: 'bn'), '💌 খাম');
    expect(
      khaamPreviewText(body, lang: 'en', reveal: (id) => id == 'other'),
      '💌 Khaam',
    );
  });

  test('opened here (or ours): the message shows', () {
    expect(
      khaamPreviewText(body, lang: 'en', reveal: (id) => id == payload.id),
      '💌 Khaam · Eid Mubarak! Warm wishes to you',
    );
  });

  test('body cut at 120 chars still hides until opened', () {
    final cut = body.substring(0, 120);
    expect(khaamPreviewText(cut, lang: 'en'), '💌 Khaam');
    final line = khaamPreviewText(cut, lang: 'en', reveal: always)!;
    expect(line, startsWith('💌 Khaam'));
    expect(line, isNot(contains('{')));
  });

  test('cut before the message shows the label alone', () {
    expect(
      khaamPreviewText(body.substring(0, 40), lang: 'en', reveal: always),
      '💌 Khaam',
    );
  });

  test('ordinary messages are left alone', () {
    expect(
      khaamPreviewText(
        '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"hi"}]}]}',
      ),
      isNull,
    );
  });
}
