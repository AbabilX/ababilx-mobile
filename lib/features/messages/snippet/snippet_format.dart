import 'dart:convert';

/// A snippet is long text sent as a file, so it is not bound by the message
/// word limit. Two formats, chosen by the sender.
enum SnippetKind {
  markdown('md', 'text/markdown'),
  text('txt', 'text/plain');

  const SnippetKind(this.extension, this.contentType);

  final String extension;
  final String contentType;
}

/// 10 MB of UTF-8, the same rule on every client.
const int maxSnippetBytes = 10 * 1024 * 1024;

/// Past this a markdown file is shown as source: laying out megabytes of
/// rendered markdown in one pass freezes the page.
const int maxRenderedMarkdownBytes = 400 * 1024;

const int _maxNameRunes = 80;
const String _defaultName = 'snippet';

/// The file name a snippet is sent under: the title with anything a file
/// system or a path would trip on removed, plus the kind's extension.
String snippetFileName(String title, SnippetKind kind) {
  var name = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // A typed extension of either kind is dropped, so "notes.txt" sent as
  // markdown is "notes.md" and not "notes.txt.md".
  name = name.replaceFirst(
    RegExp(r'\.(md|markdown|txt)$', caseSensitive: false),
    '',
  );
  name = name.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (name.runes.length > _maxNameRunes) {
    name = String.fromCharCodes(name.runes.take(_maxNameRunes)).trim();
  }
  if (name.isEmpty) name = _defaultName;
  return '$name.${kind.extension}';
}

/// The kind a file name says it is, or null when it is not a snippet.
SnippetKind? snippetKindOf(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
    return SnippetKind.markdown;
  }
  if (lower.endsWith('.txt')) return SnippetKind.text;
  return null;
}

/// Whether an attachment is drawn as a snippet card. Decided by the name, so a
/// `.md` or `.txt` picked through Files or sent from the web gets the card too.
bool isSnippetFile(String fileName, int sizeBytes) =>
    snippetKindOf(fileName) != null && sizeBytes <= maxSnippetBytes;

int snippetByteLength(String content) => utf8.encode(content).length;

bool isSnippetTooLarge(String content) =>
    snippetByteLength(content) > maxSnippetBytes;

/// The first [maxLines] non-empty lines of [head], for the card in the bubble.
/// [head] is only the start of the file, so the last line may be cut short.
String snippetPreview(String head, {int maxLines = 5, int maxLineRunes = 120}) {
  final lines = <String>[];
  for (final raw in const LineSplitter().convert(head)) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    lines.add(
      line.runes.length > maxLineRunes
          ? String.fromCharCodes(line.runes.take(maxLineRunes))
          : line,
    );
    if (lines.length == maxLines) break;
  }
  return lines.join('\n');
}
