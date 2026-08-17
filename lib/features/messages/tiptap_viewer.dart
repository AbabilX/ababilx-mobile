import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'tiptap_blocks.dart';
import 'tiptap_inline.dart';
import 'tiptap_plain_text.dart';

/// Renders TipTap / ProseMirror JSON as Flutter widgets (read-only).
///
/// This is the single body renderer for chat, the wall and kanban, so bold,
/// lists, headings, quotes and code survive on mobile exactly as the author
/// typed them on web. Anything that flattens a body to a string is a preview,
/// not a body — use [tiptapToPreviewText] there instead.
class TiptapViewer extends StatefulWidget {
  const TiptapViewer({
    super.key,
    required this.content,
    this.style,
    this.emptyPlaceholder,
    this.trailing,
    this.maxHeight,
  });

  final String? content;
  final TextStyle? style;

  /// Shown when the body is empty. Null renders nothing — a chat row has other
  /// parts (attachments, reactions) and must not claim "No description".
  final String? emptyPlaceholder;

  /// Appended to the end of the last text block, e.g. the "(edited)" marker.
  final InlineSpan? trailing;

  /// Clips the body to this height, for collapsed cards.
  final double? maxHeight;

  @override
  State<TiptapViewer> createState() => _TiptapViewerState();
}

class _TiptapViewerState extends State<TiptapViewer> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Every build rebuilds its spans, so the previous recognizers are dead.
    _disposeRecognizers();

    final theme = Theme.of(context);
    final base =
        widget.style ??
        theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ) ??
        const TextStyle(height: 1.5);

    final trimmed = widget.content?.trim() ?? '';
    if (trimmed.isEmpty || isTiptapEmpty(trimmed)) return _empty(base);

    final inline = TiptapInline(
      context: context,
      baseStyle: base,
      onRecognizer: _recognizers.add,
    );
    final blocks = TiptapBlocks(
      context: context,
      baseStyle: base,
      inline: inline,
    );

    final doc = _decodeDoc(trimmed);
    if (doc == null) return _clip(_fallback(trimmed, base, inline));

    final built = blocks.buildDoc(doc, trailing: widget.trailing);
    if (built.isEmpty) return _empty(base);
    return _clip(blocks.column(built));
  }

  /// A body that is not TipTap JSON is legacy plain text — still linkified so
  /// old messages do not lose their tappable URLs.
  Widget _fallback(String value, TextStyle base, TiptapInline inline) {
    final text = tiptapToPlainText(value);
    final spans = inline.linkify(text, base);
    final trailing = widget.trailing;
    return Text.rich(
      TextSpan(
        style: base,
        children: trailing == null ? spans : [...spans, trailing],
      ),
    );
  }

  Map<String, dynamic>? _decodeDoc(String value) {
    if (!value.startsWith('{') || !value.contains('"type"')) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final doc = Map<String, dynamic>.from(decoded);
      return doc['type'] == 'doc' ? doc : null;
    } catch (_) {
      return null;
    }
  }

  Widget _clip(Widget child) {
    final maxHeight = widget.maxHeight;
    if (maxHeight == null) return child;
    // The scroll view is what gives the body unbounded height to lay out in;
    // a plain ConstrainedBox would overflow instead of clipping.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: child,
      ),
    );
  }

  Widget _empty(TextStyle base) {
    final placeholder = widget.emptyPlaceholder;
    if (placeholder == null) return const SizedBox.shrink();
    return Text(
      placeholder,
      style: base.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
