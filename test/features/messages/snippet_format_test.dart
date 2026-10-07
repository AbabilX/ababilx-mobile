import 'package:ababilx/features/messages/snippet/snippet_file_reader.dart';
import 'package:ababilx/features/messages/snippet/snippet_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file name comes from the title and the kind', () {
    expect(snippetFileName('', SnippetKind.markdown), 'snippet.md');
    expect(
      snippetFileName('  Deploy notes ', SnippetKind.text),
      'Deploy notes.txt',
    );
    expect(snippetFileName('notes.txt', SnippetKind.markdown), 'notes.md');
    expect(snippetFileName('a/b\\c:d', SnippetKind.text), 'a b c d.txt');
    expect(snippetFileName('...', SnippetKind.text), 'snippet.txt');
    expect(snippetFileName('বাংলা নোট', SnippetKind.markdown), 'বাংলা নোট.md');
  });

  test('a long title is cut to 80 characters', () {
    final name = snippetFileName('x' * 200, SnippetKind.text);
    expect(name, '${'x' * 80}.txt');
  });

  test('kind is read off the extension', () {
    expect(snippetKindOf('README.MD'), SnippetKind.markdown);
    expect(snippetKindOf('a.markdown'), SnippetKind.markdown);
    expect(snippetKindOf('log.txt'), SnippetKind.text);
    expect(snippetKindOf('photo.jpg'), isNull);
    expect(snippetKindOf('file'), isNull);
  });

  test('only a text file within 10 MB is a snippet', () {
    expect(isSnippetFile('a.md', 10), isTrue);
    expect(isSnippetFile('a.txt', maxSnippetBytes), isTrue);
    expect(isSnippetFile('a.txt', maxSnippetBytes + 1), isFalse);
    expect(isSnippetFile('a.pdf', 10), isFalse);
  });

  test('size is counted in UTF-8 bytes', () {
    expect(snippetByteLength('abc'), 3);
    expect(snippetByteLength('বাং'), 9);
    expect(isSnippetTooLarge('a' * maxSnippetBytes), isFalse);
    expect(isSnippetTooLarge('a' * (maxSnippetBytes + 1)), isTrue);
  });

  test('preview keeps the first non-empty lines', () {
    expect(snippetPreview('\n# Title\n\nbody  \nmore'), '# Title\nbody\nmore');
    expect(snippetPreview('1\n2\n3\n4\n5\n6\n7').split('\n').length, 5);
    expect(snippetPreview('y' * 500).length, 120);
    expect(snippetPreview(''), '');
  });

  test('a line with no breaks is cut into rows, never inside an emoji', () {
    expect(splitSnippetRows('a\n\nb'), ['a', '', 'b']);
    final rows = splitSnippetRows('x' * 4500, maxChars: 2000);
    expect(rows.map((r) => r.length), [2000, 2000, 500]);
    // "😀" is two UTF-16 units; a cut at 3 would land between them.
    final emoji = splitSnippetRows('ab😀cd', maxChars: 3);
    expect(emoji, ['ab', '😀c', 'd']);
    expect(emoji.join(), 'ab😀cd');
  });
}
