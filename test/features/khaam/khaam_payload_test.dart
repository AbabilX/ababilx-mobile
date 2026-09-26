import 'package:ababilx/features/khaam/data/khaam_payload.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:ababilx/features/messages/tiptap_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payload = KhaamPayload(
    id: 'jp-1',
    coverId: 'eid',
    message: 'ঈদ মোবারক!',
  );

  test('round-trips through the message body', () {
    final parsed = KhaamPayload.tryParse(encodeKhaamBody(payload))!;
    expect(parsed.id, 'jp-1');
    expect(parsed.coverId, 'eid');
    expect(parsed.message, 'ঈদ মোবারক!');
    expect(parsed.lang, 'bn');
  });

  test('carries no money', () {
    expect(encodeKhaamBody(payload), isNot(contains('amount')));
    expect(encodeKhaamBody(payload), isNot(contains('৳')));
  });

  test('the fallback line never carries the message', () {
    // Web, desktop, search and older builds read this line. The message is
    // a surprise until the receiver scratches the card open.
    expect(tiptapToPlainText(encodeKhaamBody(payload)), '💌 খাম');
    expect(encodeKhaamBody(payload), contains('ঈদ মোবারক!')); // in attrs only
    expect(
      const KhaamPayload(
        id: 'x',
        coverId: 'classic',
        message: 'hi',
        lang: 'en',
      ).fallbackText,
      '💌 Khaam',
    );
  });

  test('notifications and quotes hide the message of an old card too', () {
    // Sent before 2026-09-26: the fallback paragraph still holds the text.
    const old =
        '{"type":"doc","attrs":{"jpack":{"v":2,"id":"o","cover":"eid",'
        '"message":"secret","lang":"en"}},"content":[{"type":"paragraph",'
        '"content":[{"type":"text","text":"💌 JPack · secret"}]}]}';
    expect(tiptapToPreviewText(old), '💌 Khaam');
  });

  test('the wire key stays jpack so sent cards keep opening', () {
    expect(khaamWireKey, 'jpack');
    expect(encodeKhaamBody(payload), contains('"jpack"'));
  });

  test('a Khaam sent by an older build still opens as a card', () {
    final parsed = KhaamPayload.tryParse(
      '{"type":"doc","attrs":{"jpack":{"v":1,"id":"old","cover":"eid",'
      '"amount":500,"currency":"BDT","message":"hi"}}}',
    )!;
    expect(parsed.id, 'old');
    expect(parsed.message, 'hi');
  });

  test('ordinary messages are not Khaams', () {
    expect(KhaamPayload.tryParse(null), isNull);
    expect(KhaamPayload.tryParse(''), isNull);
    expect(KhaamPayload.tryParse('hello khaam'), isNull);
    expect(KhaamPayload.tryParse(encodeTiptapBody(plain: 'hi')), isNull);
    // A user typing the word inside ordinary text.
    expect(
      KhaamPayload.tryParse(encodeTiptapBody(plain: '"jpack" {"type"}')),
      isNull,
    );
  });

  test('a malformed Khaam is rejected', () {
    expect(
      KhaamPayload.tryParse('{"type":"doc","attrs":{"jpack":{"id":""}}}'),
      isNull,
    );
    expect(
      KhaamPayload.tryParse('{"type":"doc","attrs":{"jpack":{"cover":"eid"}}}'),
      isNull,
    );
    expect(KhaamPayload.tryParse('{"type":"doc","attrs":{"jpack":'), isNull);
  });
}
