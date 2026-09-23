import 'package:flutter/material.dart';

import '../mention_boundary.dart';

const _email = r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+';

/// A range of the draft to paint as a chip: a picked mention or a link.
class ComposerHighlight {
  const ComposerHighlight(this.start, this.end, {required this.isMention});

  final int start;
  final int end;
  final bool isMention;
}

/// Links, emails and the `@Label` runs of mentions actually picked from the
/// popover. A typed `@word` nobody picked stays plain: it notifies nobody, so
/// painting it would promise a mention that will not happen.
List<ComposerHighlight> findComposerHighlights(
  String text,
  Iterable<String> mentionLabels,
) {
  if (text.isEmpty) return const [];
  final labels = [
    for (final l in mentionLabels)
      if (l.trim().isNotEmpty) l,
  ]..sort((a, b) => b.length.compareTo(a.length));
  final mention = labels.isEmpty
      ? ''
      // The end rule is the encoder's `mentionEndsAt`: paint exactly what the
      // send will turn into a mention, so "@Sharmin Sornax" is not a chip.
      : '|(?<![A-Za-z0-9_.+\\-])(?:${labels.map((l) => '@${RegExp.escape(l)}').join('|')})$mentionEndLookahead';
  final pattern = RegExp(
    'https?://[^\\s]+|www\\.[^\\s]+|$_email$mention',
    unicode: true,
  );
  return [
    for (final m in pattern.allMatches(text))
      ComposerHighlight(m.start, m.end, isMention: m.group(0)!.startsWith('@')),
  ];
}

/// The composer's controller: draws mentions and links on a tinted
/// background while typing, the way they will read once sent.
class ComposerHighlightController extends TextEditingController {
  ComposerHighlightController({super.text, required this.mentionLabels});

  /// Read on every build, so a mention picked a moment ago paints at once.
  final Iterable<String> Function() mentionLabels;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final highlights = findComposerHighlights(text, mentionLabels());
    if (highlights.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final chip = (style ?? const TextStyle()).copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w600,
      // Strong enough to read on the dark pill, where 16% vanished.
      backgroundColor: colors.primary.withValues(alpha: 0.32),
    );
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;

    // Cut at every highlight and composing edge, then style each piece.
    final cuts = <int>{0, text.length};
    for (final h in highlights) {
      cuts
        ..add(h.start)
        ..add(h.end);
    }
    if (composing.isValid) {
      cuts
        ..add(composing.start)
        ..add(composing.end);
    }
    final sorted = cuts.toList()..sort();

    final children = <TextSpan>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start >= end) continue;
      final inChip = highlights.any((h) => start >= h.start && end <= h.end);
      var pieceStyle = inChip ? chip : style;
      if (composing.isValid &&
          start >= composing.start &&
          end <= composing.end) {
        pieceStyle = (pieceStyle ?? const TextStyle()).merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      var piece = text.substring(start, end);
      // A mention wraps as one word: its spaces are drawn non-breaking. Same
      // length, so every caret and selection offset still lines up.
      if (inChip && piece.contains(' ') && _inMention(highlights, start)) {
        piece = piece.replaceAll(' ', '\u00A0');
      }
      children.add(TextSpan(text: piece, style: pieceStyle));
    }
    return TextSpan(style: style, children: children);
  }
}

bool _inMention(List<ComposerHighlight> highlights, int offset) =>
    highlights.any((h) => h.isMention && offset >= h.start && offset < h.end);
