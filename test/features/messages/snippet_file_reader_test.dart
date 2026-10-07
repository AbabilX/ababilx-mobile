import 'dart:io';

import 'package:ababilx/features/messages/snippet/snippet_file_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('snippet_reader'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the whole text is kept only for a file under the limit', () async {
    final file = File('${dir.path}/a.md')..writeAsStringSync('one\ntwo\n');
    final small = await readSnippetFile(file.path, keepTextUpToBytes: 100);
    expect(small.text, 'one\ntwo\n');
    expect(small.lines, ['one', 'two']);

    final large = await readSnippetFile(file.path, keepTextUpToBytes: 3);
    expect(large.text, isNull);
    expect(large.lines, ['one', 'two']);
    expect(large.sizeBytes, 8);

    expect((await readSnippetFile(file.path)).text, isNull);
  });

  test('copy reads the file exactly as written', () async {
    final long = 'x' * (maxSnippetRowChars + 5);
    final file = File('${dir.path}/b.txt')..writeAsStringSync('$long\r\nend');
    expect((await readSnippetFile(file.path)).lines.length, 3);
    expect(await readSnippetText(file.path), '$long\r\nend');
  });
}
