import 'package:ababilx/features/messages/markdown/markdown_head.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a short body is returned as it is', () {
    const body = 'Hello **there**\n\n- one\n- two';
    expect(identical(markdownHead(body), body), isTrue);
  });

  test('a long body is cut at a line break, well past a screenful', () {
    final body = List.generate(
      400,
      (i) => 'line number $i of the message',
    ).join('\n');
    final head = markdownHead(body);
    expect(head.length, lessThanOrEqualTo(2400));
    expect(body.startsWith(head), isTrue);
    expect(body[head.length], '\n');
    expect('\n'.allMatches(head).length, greaterThan(20));
  });

  test('many short lines stop at the line limit', () {
    final body = List.filled(500, 'a').join('\n');
    final head = markdownHead(body);
    expect(head.split('\n').length, 48);
  });

  test('one unbroken run is cut by length, never inside an emoji', () {
    final body = '😀' * 3000; // two code units each
    final head = markdownHead(body, maxChars: 2401);
    expect(head.length, 2400);
    expect(head.runes.every((r) => r == 0x1F600), isTrue);
  });

  test('a code fence the cut left open is closed', () {
    final code = List.generate(300, (i) => 'print($i);').join('\n');
    final head = markdownHead('Intro\n```dart\n$code\n```\nAfter');
    expect(head.endsWith('\n```'), isTrue);
    expect('```'.allMatches(head).length, 2);
  });

  test('a fence closed before the cut is left alone', () {
    final tail = List.generate(300, (i) => 'paragraph $i').join('\n');
    final head = markdownHead('```\ncode\n```\n$tail');
    expect('```'.allMatches(head).length, 2);
    expect(head.endsWith('```'), isFalse);
  });

  test('a fence inside a quote counts', () {
    final code = List.generate(300, (i) => '> row $i').join('\n');
    final head = markdownHead('> ```\n$code');
    expect(head.endsWith('\n```'), isTrue);
  });
}
