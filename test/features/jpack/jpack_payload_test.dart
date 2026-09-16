import 'package:ababilx/features/jpack/data/jpack_payload.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:ababilx/features/messages/tiptap_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payload = JPackPayload(
    id: 'jp-1',
    coverId: 'eid',
    message: 'ঈদ মোবারক!',
  );

  test('round-trips through the message body', () {
    final parsed = JPackPayload.tryParse(encodeJPackBody(payload))!;
    expect(parsed.id, 'jp-1');
    expect(parsed.coverId, 'eid');
    expect(parsed.message, 'ঈদ মোবারক!');
    expect(parsed.lang, 'bn');
  });

  test('carries no money', () {
    expect(encodeJPackBody(payload), isNot(contains('amount')));
    expect(encodeJPackBody(payload), isNot(contains('৳')));
  });

  test('clients without JPack read the fallback line', () {
    expect(
      tiptapToPlainText(encodeJPackBody(payload)),
      '🧧 JPack — ঈদ মোবারক!',
    );
    expect(
      const JPackPayload(
        id: 'x',
        coverId: 'classic',
        message: ' ',
      ).fallbackText,
      '🧧 JPack',
    );
  });

  test('a JPack sent by an older build still opens as a card', () {
    final parsed = JPackPayload.tryParse(
      '{"type":"doc","attrs":{"jpack":{"v":1,"id":"old","cover":"eid",'
      '"amount":500,"currency":"BDT","message":"hi"}}}',
    )!;
    expect(parsed.id, 'old');
    expect(parsed.message, 'hi');
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

  test('a malformed JPack is rejected', () {
    expect(
      JPackPayload.tryParse('{"type":"doc","attrs":{"jpack":{"id":""}}}'),
      isNull,
    );
    expect(
      JPackPayload.tryParse('{"type":"doc","attrs":{"jpack":{"cover":"eid"}}}'),
      isNull,
    );
    expect(JPackPayload.tryParse('{"type":"doc","attrs":{"jpack":'), isNull);
  });
}
