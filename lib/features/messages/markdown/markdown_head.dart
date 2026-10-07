/// The start of [source]: enough to fill a collapsed bubble and no more.
///
/// A collapsed body is clipped to a fixed height, but a clip only hides. The
/// whole document was still parsed and laid out behind it on every rebuild,
/// and a message may be 6000 words. The full text is one tap away
/// (`LongMessageScreen`), which builds it once.
///
/// Cut at a line break where there is one, never inside a surrogate pair. A
/// code fence left open by the cut is closed, so the text after the cut cannot
/// change how the visible part is drawn.
String markdownHead(String source, {int maxChars = 2400, int maxLines = 48}) {
  var end = -1;
  var lines = 0;
  final scan = source.length < maxChars ? source.length : maxChars;
  for (var i = 0; i < scan; i++) {
    if (source.codeUnitAt(i) == 0x0A && ++lines == maxLines) {
      end = i;
      break;
    }
  }
  if (end < 0) {
    if (source.length <= maxChars) return source;
    end = maxChars;
    final lineBreak = source.lastIndexOf('\n', end);
    if (lineBreak > maxChars ~/ 2) {
      end = lineBreak;
    } else if (_isHighSurrogate(source.codeUnitAt(end - 1))) {
      end -= 1;
    }
  }
  final head = source.substring(0, end);
  return _fenceOpen(head) ? '$head\n```' : head;
}

/// Whether [text] ends inside a fenced code block: an odd number of fence
/// lines. A fence may sit inside a quote or a list item, so its markers and
/// indent are skipped first.
bool _fenceOpen(String text) {
  var fences = 0;
  for (final line in text.split('\n')) {
    if (line.replaceFirst(_fenceLead, '').startsWith('```')) fences++;
  }
  return fences.isOdd;
}

final _fenceLead = RegExp(r'^[\s>]*');

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
