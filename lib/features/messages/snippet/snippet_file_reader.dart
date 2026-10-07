import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// A snippet file as the viewer draws it.
class SnippetFile {
  const SnippetFile({
    required this.text,
    required this.lines,
    required this.sizeBytes,
  });

  /// The whole text, kept only for a file small enough to draw formatted
  /// (see [readSnippetFile]). Null for a larger one: [lines] already holds
  /// every character, and a second copy of ten megabytes buys nothing.
  final String? text;

  /// The text cut into rows for a lazy list. A line longer than
  /// [maxSnippetRowChars] is split, see [splitSnippetRows].
  final List<String> lines;
  final int sizeBytes;
}

/// The most characters one row holds. A minified file or a log with no line
/// breaks is a single "line" of megabytes, and one Text that long is laid out
/// whole before the first frame.
const int maxSnippetRowChars = 2000;

/// Reads and decodes off the UI isolate: ten megabytes of UTF-8 is long
/// enough to drop frames on the page transition. The whole text comes back
/// beside the rows only when the file is at most [keepTextUpToBytes].
Future<SnippetFile> readSnippetFile(String path, {int keepTextUpToBytes = 0}) =>
    Isolate.run(() async {
      final bytes = await File(path).readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      return SnippetFile(
        text: bytes.length <= keepTextUpToBytes ? text : null,
        lines: splitSnippetRows(text),
        sizeBytes: bytes.length,
      );
    });

/// The file's text exactly as written, for Copy. Read again from the disk
/// rather than held for as long as the page is open.
Future<String> readSnippetText(String path) => Isolate.run(
  () async => utf8.decode(await File(path).readAsBytes(), allowMalformed: true),
);

/// Lines of [text], with any line over [maxChars] cut into pieces. A cut never
/// lands inside a surrogate pair, so an emoji is not torn in two.
List<String> splitSnippetRows(
  String text, {
  int maxChars = maxSnippetRowChars,
}) {
  final rows = <String>[];
  for (final line in const LineSplitter().convert(text)) {
    if (line.length <= maxChars) {
      rows.add(line);
      continue;
    }
    var start = 0;
    while (start < line.length) {
      var end = start + maxChars;
      if (end >= line.length) {
        end = line.length;
      } else if (_isHighSurrogate(line.codeUnitAt(end - 1))) {
        end -= 1;
      }
      rows.add(line.substring(start, end));
      start = end;
    }
  }
  return rows;
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
