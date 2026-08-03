import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tiptap_plain_text.dart';

/// Renders TipTap / ProseMirror JSON as Flutter widgets (read-only).
class TiptapViewer extends StatelessWidget {
  const TiptapViewer({super.key, required this.content, this.style});

  final String? content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        style ??
        theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: theme.colorScheme.onSurface,
        );

    final trimmed = content?.trim() ?? '';
    if (trimmed.isEmpty || isTiptapEmpty(trimmed)) {
      return Text(
        'No description',
        style: base?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (!_isTiptapJson(trimmed)) {
      return Text(trimmed, style: base);
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return Text(tiptapToPlainText(trimmed), style: base);
      }
      final doc = Map<String, dynamic>.from(decoded);
      if (doc['type'] != 'doc') {
        return Text(tiptapToPlainText(trimmed), style: base);
      }
      final blocks = _TiptapRenderer(
        context: context,
        baseStyle: base!,
      ).buildDoc(doc);
      if (blocks.isEmpty) {
        return Text(
          'No description',
          style: base.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      );
    } catch (_) {
      return Text(tiptapToPlainText(trimmed), style: base);
    }
  }
}

bool _isTiptapJson(String value) {
  final t = value.trim();
  return t.startsWith('{') && t.contains('"type"');
}

class _TiptapRenderer {
  _TiptapRenderer({required this.context, required this.baseStyle});

  final BuildContext context;
  final TextStyle baseStyle;

  List<Widget> buildDoc(Map<String, dynamic> doc) {
    final content = doc['content'];
    if (content is! List) return [];
    return content
        .whereType<Map>()
        .map((n) => _buildBlock(Map<String, dynamic>.from(n)))
        .whereType<Widget>()
        .toList();
  }

  Widget? _buildBlock(Map<String, dynamic> node) {
    final type = node['type'] as String?;
    switch (type) {
      case 'paragraph':
        return _paragraph(node, top: 0, bottom: 8);
      case 'heading':
        return _heading(node);
      case 'bulletList':
        return _bulletList(node);
      case 'orderedList':
        return _orderedList(node);
      case 'blockquote':
        return _blockquote(node);
      case 'codeBlock':
        return _codeBlock(node);
      case 'horizontalRule':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        );
      case 'taskList':
        return _taskList(node);
      default:
        final inline = _inlineSpans(node['content']);
        if (inline == null || inline.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(TextSpan(style: baseStyle, children: inline)),
        );
    }
  }

  Widget _paragraph(
    Map<String, dynamic> node, {
    double top = 0,
    double bottom = 8,
  }) {
    final spans = _inlineSpans(node['content']);
    if (spans == null || spans.isEmpty) {
      return SizedBox(height: bottom);
    }
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Text.rich(TextSpan(style: baseStyle, children: spans)),
    );
  }

  Widget _heading(Map<String, dynamic> node) {
    final level = (node['attrs'] as Map?)?['level'] as int? ?? 2;
    final spans =
        _inlineSpans(node['content']) ?? [TextSpan(text: '', style: baseStyle)];
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
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text.rich(TextSpan(style: style, children: spans)),
    );
  }

  Widget _bulletList(Map<String, dynamic> node) {
    final items = _listItems(node);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            _listRow(bullet: '•', child: items[i]),
        ],
      ),
    );
  }

  Widget _orderedList(Map<String, dynamic> node) {
    final items = _listItems(node);
    final start = (node['attrs'] as Map?)?['start'] as int? ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            _listRow(bullet: '${start + i}.', child: items[i]),
        ],
      ),
    );
  }

  Widget _taskList(Map<String, dynamic> node) {
    final content = node['content'];
    if (content is! List) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (final item in content.whereType<Map>())
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_box_outline_blank,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _listItemBody(Map<String, dynamic>.from(item)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _listItems(Map<String, dynamic> node) {
    final content = node['content'];
    if (content is! List) return [];
    return content
        .whereType<Map>()
        .map((n) => _listItemBody(Map<String, dynamic>.from(n)))
        .toList();
  }

  Widget _listItemBody(Map<String, dynamic> node) {
    final inner = node['content'];
    if (inner is! List) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in inner.whereType<Map>())
          _buildBlock(Map<String, dynamic>.from(child)) ??
              const SizedBox.shrink(),
      ],
    );
  }

  Widget _listRow({required String bullet, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(bullet, style: baseStyle.copyWith(height: 1.5)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _blockquote(Map<String, dynamic> node) {
    final colors = Theme.of(context).colorScheme;
    final inner = node['content'];
    final children = <Widget>[];
    if (inner is List) {
      for (final child in inner.whereType<Map>()) {
        final w = _buildBlock(Map<String, dynamic>.from(child));
        if (w != null) children.add(w);
      }
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colors.primary.withValues(alpha: 0.55),
            width: 3,
          ),
        ),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _codeBlock(Map<String, dynamic> node) {
    final colors = Theme.of(context).colorScheme;
    final text = _plainFromContent(node['content']);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: (baseStyle.fontSize ?? 14) - 1,
        ),
      ),
    );
  }

  String _plainFromContent(dynamic content) {
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .map((n) => _nodeToPlain(Map<String, dynamic>.from(n)))
        .join('');
  }

  String _nodeToPlain(Map<String, dynamic> node) {
    final type = node['type'];
    if (type == 'hardBreak') return '\n';
    if (type == 'text') return node['text'] as String? ?? '';
    final inner = node['content'];
    if (inner is! List) return '';
    return inner
        .whereType<Map>()
        .map((n) => _nodeToPlain(Map<String, dynamic>.from(n)))
        .join();
  }

  List<InlineSpan>? _inlineSpans(dynamic content) {
    if (content is! List || content.isEmpty) return null;
    final spans = <InlineSpan>[];
    for (final raw in content) {
      if (raw is! Map) continue;
      final node = Map<String, dynamic>.from(raw);
      final span = _inlineSpan(node);
      if (span != null) spans.add(span);
    }
    return spans.isEmpty ? null : spans;
  }

  InlineSpan? _inlineSpan(Map<String, dynamic> node) {
    final type = node['type'];
    final colors = Theme.of(context).colorScheme;

    if (type == 'hardBreak') return const TextSpan(text: '\n');
    if (type == 'mention') {
      final attrs = node['attrs'];
      final label = attrs is Map
          ? (attrs['label'] ?? attrs['id'] ?? '').toString()
          : '';
      return TextSpan(
        text: '@$label',
        style: baseStyle.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (type == 'wallCategory') {
      final attrs = node['attrs'];
      final label = attrs is Map
          ? (attrs['label'] ?? attrs['id'] ?? '').toString()
          : '';
      return TextSpan(
        text: '#$label',
        style: baseStyle.copyWith(
          color: colors.tertiary,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (type != 'text') {
      final nested = _inlineSpans(node['content']);
      if (nested == null) return null;
      return TextSpan(children: nested);
    }

    var style = baseStyle;
    final marks = node['marks'];
    String? link;
    if (marks is List) {
      for (final raw in marks) {
        if (raw is! Map) continue;
        final mark = Map<String, dynamic>.from(raw);
        switch (mark['type']) {
          case 'bold':
            style = style.copyWith(fontWeight: FontWeight.w700);
          case 'italic':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'strike':
            style = style.copyWith(decoration: TextDecoration.lineThrough);
          case 'code':
            style = style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colors.surfaceContainerHighest,
            );
          case 'link':
            final href = (mark['attrs'] as Map?)?['href']?.toString();
            if (href != null && href.isNotEmpty) link = href;
            style = style.copyWith(
              color: colors.primary,
              decoration: TextDecoration.underline,
            );
        }
      }
    }

    final text = node['text'] as String? ?? '';
    if (link != null) {
      return TextSpan(
        text: text,
        style: style,
        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(link!),
      );
    }
    return TextSpan(text: text, style: style);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
