import 'package:flutter/material.dart';

import 'tiptap_inline.dart';

part 'tiptap_blocks_lists.dart';

/// Vertical rhythm between blocks. Applied *between* siblings only, never
/// after the last one — a trailing gap is visible inside a chat row.
const _blockGap = 8.0;

/// Block half of the TipTap renderer: paragraphs, headings, lists, quotes.
class TiptapBlocks {
  TiptapBlocks({
    required this.context,
    required this.baseStyle,
    required this.inline,
  });

  final BuildContext context;
  final TextStyle baseStyle;
  final TiptapInline inline;

  /// Appended to the last text block — the "(edited)" marker rides the end of
  /// the body on web rather than sitting on a line of its own.
  InlineSpan? _trailing;

  List<Widget> buildDoc(Map<String, dynamic> doc, {InlineSpan? trailing}) {
    final content = doc['content'];
    if (content is! List) return const [];
    final nodes = content.whereType<Map>().toList();
    final blocks = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      _trailing = i == nodes.length - 1 ? trailing : null;
      final block = buildBlock(Map<String, dynamic>.from(nodes[i]));
      if (block != null) blocks.add(block);
    }
    _trailing = null;
    return blocks;
  }

  List<InlineSpan> _withTrailing(List<InlineSpan> spans) {
    final trailing = _trailing;
    if (trailing == null) return spans;
    _trailing = null;
    return [...spans, trailing];
  }

  /// Stacks blocks with a gap between each pair.
  Widget column(List<Widget> blocks) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: _blockGap));
      children.add(blocks[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget? buildBlock(Map<String, dynamic> node) {
    switch (node['type'] as String?) {
      case 'paragraph':
        return _paragraph(node);
      case 'heading':
        return _heading(node);
      case 'bulletList':
        return _list(node, ordered: false);
      case 'orderedList':
        return _list(node, ordered: true);
      case 'blockquote':
        return _blockquote(node);
      case 'codeBlock':
        return _codeBlock(node);
      case 'horizontalRule':
        return const Divider(height: 1);
      case 'taskList':
        return _taskList(node);
      default:
        return _paragraph(node);
    }
  }

  Widget? _paragraph(Map<String, dynamic> node) {
    final spans = inline.spansOf(node['content']);
    // An empty paragraph is a deliberate blank line on web, so keep its space.
    if (spans == null || spans.isEmpty) return const SizedBox(height: 4);
    return Text.rich(
      TextSpan(style: baseStyle, children: _withTrailing(spans)),
    );
  }

  Widget _heading(Map<String, dynamic> node) {
    final level = (node['attrs'] as Map?)?['level'] as int? ?? 2;
    final spans = inline.spansOf(node['content']) ?? const <InlineSpan>[];
    final style = switch (level) {
      1 => baseStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      2 => baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      _ => baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(TextSpan(style: style, children: _withTrailing(spans))),
    );
  }
}
