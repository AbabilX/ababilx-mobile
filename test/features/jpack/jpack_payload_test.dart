import 'package:ababilx/features/jpack/data/jpack_payload.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:ababilx/features/messages/tiptap_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payload = JPackPayload(
    id: 'jp-1',
    coverId: 'eid',
    amount: 1500,
    message: 'ঈদ মোবারক!',
  );

  test('round-trips through the message body', () {
    final parsed = JPackPayload.tryParse(encodeJPackBody(payload))!;
    expect(parsed.id, 'jp-1');
    expect(parsed.coverId, 'eid');
    expect(parsed.amount, 1500);
    expect(parsed.currency, 'BDT');
    expect(parsed.message, 'ঈদ মোবারক!');
    expect(parsed.lang, 'bn');
  });

  test('clients without JPack read the fallback line', () {
    expect(
      tiptapToPlainText(encodeJPackBody(payload)),
      '🧧 JPack · ৳1,500 — ঈদ মোবারক!',
    );
  });

  test('ordinary messages are not JPacks', () {
    expect(JPackPayload.tryParse(null), isNull);
    expect(JPackPayload.tryParse(''), isNull);
    expect(JPackPayload.tryParse('hello jpack'), isNull);
    expect(JPackPayload.tryParse(encodeTiptapBody(plain: 'hi')), isNull);
    // A user typing the word inside ordinary text.
    expect(
      JPackPayload.tryParse(encodeTiptapBody(plain: '"jpack" {"type"}')),
      isNull,
    );
  });

  test('a malformed or unpaid JPack is rejected', () {
    expect(
      JPackPayload.tryParse(
        '{"type":"doc","attrs":{"jpack":{"id":"x","amount":0}}}',
      ),
      isNull,
    );
    expect(
      JPackPayload.tryParse('{"type":"doc","attrs":{"jpack":{"amount":5}}}'),
      isNull,
    );
    expect(JPackPayload.tryParse('{"type":"doc","attrs":{"jpack":'), isNull);
  });
}
