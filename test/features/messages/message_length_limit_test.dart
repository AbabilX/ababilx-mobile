import 'package:ababilx/features/messages/message_length_limit.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts words across spaces and line breaks', () {
    expect(countMessageWords(''), 0);
    expect(countMessageWords('  one  '), 1);
    expect(countMessageWords('one two\nthree\n\n  four'), 4);
    expect(countMessageWords('আমি ভাত খাই'), 3);
  });

  test('6000 words go, 6001 do not', () {
    final ok = List.filled(maxMessageWords, 'word').join(' ');
    expect(isMessageTooLong(ok), isFalse);
    expect(isMessageTooLong('$ok more'), isTrue);
  });

  test('6000 Bangla words, one a line, fit the byte cap once encoded', () {
    final plain = List.filled(maxMessageWords, 'বাংলাদেশের').join('\n');
    final body = encodeTiptapBody(plain: plain);
    expect(isMessageTooLong(plain, encoded: body), isFalse);
  });

  test('one endless word is still refused by bytes', () {
    final plain = 'a' * (maxMessageBodyBytes + 1);
    expect(isMessageTooLong(plain), isTrue);
  });
}
