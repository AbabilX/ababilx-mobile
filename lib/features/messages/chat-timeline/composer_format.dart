import 'package:flutter/material.dart';

/// What the selection toolbar can do to the draft. The body stays markdown,
/// which is what the bubble already draws: `**bold**`, `*italic*`, `[words](url)`.
enum ComposerFormat { bold, italic, link, remove }

/// One styled run inside the draft. Offsets cover the words, never the marks,
/// so a caret on `**hi**` still lands on the same character the user sees.
class ComposerEmphasis {
  const ComposerEmphasis(
    this.start,
    this.end, {
    this.bold = false,
    this.italic = false,
    this.link = false,
  });

  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool link;

  @override
  bool operator ==(Object other) =>
      other is ComposerEmphasis &&
      other.start == start &&
      other.end == end &&
      other.bold == bold &&
      other.italic == italic &&
      other.link == link;

  @override
  int get hashCode => Object.hash(start, end, bold, italic, link);
}

const _maxLinkLength = 2048;

/// An address the sender may attach. http and https only: a `javascript:` or
/// `file:` link would be the sender's own markdown, and the bubble opens
/// whatever they typed. Userinfo is refused so `https://user:pass@host` cannot
/// hide the real host.
String? normalizeComposerLinkUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.length > _maxLinkLength) return null;
  if (RegExp(r'\s').hasMatch(trimmed)) return null;
  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri.toString();
}

/// Applies [format] to the current selection. A caret, a blank selection, or
/// a link address that does not survive [normalizeComposerLinkUrl] leaves
/// [value] untouched. The new selection sits on the words, inside the marks,
/// so a second tap of the same button takes them off.
TextEditingValue applyComposerFormat(
  TextEditingValue value, {
  required ComposerFormat format,
  String? linkUrl,
}) {
  final sel = value.selection;
  if (!sel.isValid || sel.isCollapsed) return value;
  final start = sel.start < sel.end ? sel.start : sel.end;
  final end = sel.start < sel.end ? sel.end : sel.start;
  final text = value.text;
  if (start < 0 || end > text.length || start == end) return value;

  final TextEditingValue? next = switch (format) {
    ComposerFormat.bold => _toggle(text, start, end, '**'),
    ComposerFormat.italic => _toggle(text, start, end, '*'),
    ComposerFormat.link => _link(text, start, end, linkUrl),
    ComposerFormat.remove => _removeWord(text, start, end),
  };
  return next ?? value;
}

TextEditingValue _value(String text, int start, int end) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end),
);

TextEditingValue? _toggle(String text, int start, int end, String marker) {
  final selected = text.substring(start, end);
  if (selected.contains('\n')) return _toggleLines(text, start, end, marker);
  final lead = selected.length - selected.trimLeft().length;
  final tail = selected.length - selected.trimRight().length;
  final coreStart = start + lead;
  final coreEnd = end - tail;
  if (coreStart >= coreEnd) return null;

  // `***hi***` is both. Taking one off leaves the other.
  if (_surrounded(text, coreStart, coreEnd, '***')) {
    final core = text.substring(coreStart, coreEnd);
    final kept = marker == '**' ? '*$core*' : '**$core**';
    final at = coreStart - 3 + (marker == '**' ? 1 : 2);
    return _value(
      text.replaceRange(coreStart - 3, coreEnd + 3, kept),
      at,
      at + core.length,
    );
  }
  if (_surrounded(text, coreStart, coreEnd, marker)) {
    final core = text.substring(coreStart, coreEnd);
    final at = coreStart - marker.length;
    return _value(
      text.replaceRange(
        coreStart - marker.length,
        coreEnd + marker.length,
        core,
      ),
      at,
      at + core.length,
    );
  }
  final core = text.substring(coreStart, coreEnd);
  if (_selfWrapped(core, marker)) {
    final inner = core.substring(marker.length, core.length - marker.length);
    if (inner.trim().isEmpty) return null;
    return _value(
      text.replaceRange(coreStart, coreEnd, inner),
      coreStart,
      coreStart + inner.length,
    );
  }
  return _value(
    text.replaceRange(coreStart, coreEnd, '$marker$core$marker'),
    coreStart + marker.length,
    coreStart + marker.length + core.length,
  );
}

/// Emphasis cannot cross a newline, so each line of a selection is wrapped
/// on its own. A blank line is left blank.
TextEditingValue? _toggleLines(String text, int start, int end, String marker) {
  final selected = text.substring(start, end);
  final rewritten = selected
      .split('\n')
      .map((line) {
        if (line.isEmpty) return line;
        return _toggle(line, 0, line.length, marker)?.text ?? line;
      })
      .join('\n');
  if (rewritten == selected) return null;
  return _value(
    text.replaceRange(start, end, rewritten),
    start,
    start + rewritten.length,
  );
}

bool _surrounded(String text, int start, int end, String marker) {
  if (start < marker.length || end + marker.length > text.length) return false;
  if (text.substring(start - marker.length, start) != marker) return false;
  if (text.substring(end, end + marker.length) != marker) return false;
  if (marker == '*') {
    if (start >= 2 && text[start - 2] == '*') return false;
    if (end + 1 < text.length && text[end + 1] == '*') return false;
  }
  return true;
}

bool _selfWrapped(String core, String marker) {
  if (marker == '*') {
    if (core.startsWith('**') || core.endsWith('**')) return false;
  }
  if (!core.startsWith(marker) || !core.endsWith(marker)) return false;
  if (core.length <= marker.length * 2) return false;
  return core
      .substring(marker.length, core.length - marker.length)
      .trim()
      .isNotEmpty;
}

final _linkPattern = RegExp(r'\[([^\[\]\n]+)\]\((https?:\/\/[^)\s]+)\)');

TextEditingValue? _link(String text, int start, int end, String? linkUrl) {
  final url = linkUrl == null ? null : normalizeComposerLinkUrl(linkUrl);
  if (url == null) return null;
  for (final match in _linkPattern.allMatches(text)) {
    if (start >= match.start && end <= match.end) {
      final label = match.group(1)!;
      final at = match.start + 1;
      return _value(
        text.replaceRange(match.start, match.end, '[$label]($url)'),
        at,
        at + label.length,
      );
    }
  }
  final selected = text.substring(start, end);
  final lead = selected.length - selected.trimLeft().length;
  final tail = selected.length - selected.trimRight().length;
  final coreStart = start + lead;
  final coreEnd = end - tail;
  if (coreStart >= coreEnd) return null;
  final label = text
      .substring(coreStart, coreEnd)
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim()
      .replaceAll('[', '(')
      .replaceAll(']', ')');
  if (label.trim().isEmpty) return null;
  final at = coreStart + 1;
  return _value(
    text.replaceRange(coreStart, coreEnd, '[$label]($url)'),
    at,
    at + label.length,
  );
}

/// Deletes the selection. Marks that exist only to wrap that word go with it,
/// and one neighbouring space goes too, so "say hello there" does not become
/// "say  there".
TextEditingValue? _removeWord(String text, int start, int end) {
  var (from, to) = _absorb(text, start, end);
  final lineStart = from == 0 || text[from - 1] == '\n';
  final lineEnd = to == text.length || text[to] == '\n';
  if (lineStart && lineEnd) {
    // The selection is a whole line. Take its break so a blank line is not
    // left behind.
    if (to < text.length && text[to] == '\n') {
      to += 1;
    } else if (from > 0 && text[from - 1] == '\n') {
      from -= 1;
    }
  } else if (from > 0 &&
      to < text.length &&
      text[from - 1] == ' ' &&
      text[to] == ' ') {
    to += 1;
  } else if (from == 0 && to < text.length && text[to] == ' ') {
    to += 1;
  } else if (to == text.length && from > 0 && text[from - 1] == ' ') {
    from -= 1;
  }
  if (from >= to) return null;
  final next = text.replaceRange(from, to, '');
  final caret = from.clamp(0, next.length);
  return _value(next, caret, caret);
}

(int, int) _absorb(String text, int start, int end) {
  var from = start;
  var to = end;
  for (var guard = 0; guard < 8; guard++) {
    var moved = false;
    for (final marker in ['***', '**', '~~', '`', '*']) {
      if (from < marker.length || to + marker.length > text.length) continue;
      if (text.substring(from - marker.length, from) != marker) continue;
      if (text.substring(to, to + marker.length) != marker) continue;
      if (marker == '*') {
        if (from >= 2 && text[from - 2] == '*') continue;
        if (to + 1 < text.length && text[to + 1] == '*') continue;
      }
      from -= marker.length;
      to += marker.length;
      moved = true;
    }
    if (from > 0 && text[from - 1] == '[') {
      final tail = RegExp(
        r'^\]\((https?:\/\/[^)\s]+)\)',
      ).matchAsPrefix(text, to);
      if (tail != null) {
        from -= 1;
        to = tail.end;
        moved = true;
      }
    }
    if (!moved) break;
  }
  return (from, to);
}

/// Bold, italic and link labels in [text], for the draft painter. Marks inside
/// `` `code` `` are left alone: those stars are the words, not formatting.
List<ComposerEmphasis> findComposerEmphasis(String text) {
  if (text.isEmpty) return const [];
  final blocked = <(int, int)>[];
  bool overlaps(int start, int end) =>
      blocked.any((range) => start < range.$2 && end > range.$1);
  for (final match in RegExp(r'`([^`\n]+)`').allMatches(text)) {
    blocked.add((match.start, match.end));
  }
  final found = <ComposerEmphasis>[];
  void add(
    RegExp pattern,
    int pad, {
    bool bold = false,
    bool italic = false,
    bool link = false,
  }) {
    for (final match in pattern.allMatches(text)) {
      final inner = match.group(1);
      if (inner == null || inner.isEmpty) continue;
      if (overlaps(match.start, match.end)) continue;
      final start = match.start + pad;
      final end = start + inner.length;
      if (end > match.end) continue;
      blocked.add((match.start, match.end));
      found.add(
        ComposerEmphasis(start, end, bold: bold, italic: italic, link: link),
      );
    }
  }

  add(RegExp(r'\*\*\*(.+?)\*\*\*'), 3, bold: true, italic: true);
  add(RegExp(r'\*\*(.+?)\*\*'), 2, bold: true);
  add(RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'), 1, italic: true);
  add(_linkPattern, 1, link: true);
  return found;
}
