import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Link blue, shared by every surface that renders a body.
const tiptapLinkColor = Color(0xFF64B5F6);

/// Web autolinks URLs while they are typed, so a bare URL there carries a
/// `link` mark. Text composed on mobile never does, and the same message would
/// read as dead text — link bare URLs at render time so both look alike.
final _bareUrlRe = RegExp(r'https?:\/\/[^\s<>\[\]()"]+', caseSensitive: false);
final _urlTrailRe = RegExp(r'[.,;!?)]+$');

/// Inline half of the TipTap renderer: text nodes, marks, mentions, links.
class TiptapInline {
  TiptapInline({
    required this.context,
    required this.baseStyle,
    required this.onRecognizer,
  });

  final BuildContext context;
  final TextStyle baseStyle;

  /// Handed every recognizer built here so the owning widget can dispose them.
  final ValueChanged<TapGestureRecognizer> onRecognizer;

  List<InlineSpan>? spansOf(dynamic content) {
    if (content is! List || content.isEmpty) return null;
    final spans = <InlineSpan>[];
    for (final raw in content) {
      if (raw is! Map) continue;
      spans.addAll(_spansOfNode(Map<String, dynamic>.from(raw)));
    }
    return spans.isEmpty ? null : spans;
  }

  /// Flattens a node list to text — code blocks keep their source verbatim.
  String plainOf(dynamic content) {
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .map((n) => _nodeToPlain(Map<String, dynamic>.from(n)))
        .join();
  }

  List<InlineSpan> linkify(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _bareUrlRe.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      var url = match.group(0)!;
      final trailing = _urlTrailRe.firstMatch(url)?.group(0) ?? '';
      if (trailing.isNotEmpty) {
        url = url.substring(0, url.length - trailing.length);
      }
      spans.add(linkSpan(url, url, _linkStyle(style)));
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing, style: style));
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }

  InlineSpan linkSpan(String text, String href, TextStyle style) {
    final recognizer = TapGestureRecognizer()..onTap = () => _open(href);
    onRecognizer(recognizer);
    return TextSpan(text: text, style: style, recognizer: recognizer);
  }

  TextStyle _linkStyle(TextStyle style) => style.copyWith(
    color: tiptapLinkColor,
    decoration: TextDecoration.underline,
    decorationColor: tiptapLinkColor.withValues(alpha: 0.45),
  );

  List<InlineSpan> _spansOfNode(Map<String, dynamic> node) {
    final type = node['type'];
    if (type == 'hardBreak') return const [TextSpan(text: '\n')];
    if (type == 'mention' || type == 'wallCategory') {
      return [_tagSpan(node, mention: type == 'mention')];
    }
    if (type != 'text') {
      final nested = spansOf(node['content']);
      return nested == null ? const [] : [TextSpan(children: nested)];
    }
    return _textSpans(node);
  }

  InlineSpan _tagSpan(Map<String, dynamic> node, {required bool mention}) {
    final colors = Theme.of(context).colorScheme;
    final attrs = node['attrs'];
    final label = attrs is Map
        ? (attrs['label'] ?? attrs['id'] ?? '').toString()
        : '';
    return TextSpan(
      text: '${mention ? '@' : '#'}$label',
      style: baseStyle.copyWith(
        color: mention ? colors.primary : colors.tertiary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  List<InlineSpan> _textSpans(Map<String, dynamic> node) {
    final text = node['text'] as String? ?? '';
    if (text.isEmpty) return const [];

    final colors = Theme.of(context).colorScheme;
    // Decorations accumulate: strikethrough plus a link underline are both
    // possible on one span, and copyWith would keep only the last one.
    final decorations = <TextDecoration>[];
    var style = baseStyle;
    String? href;

    final marks = node['marks'];
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
            decorations.add(TextDecoration.lineThrough);
          case 'underline':
            decorations.add(TextDecoration.underline);
          case 'code':
            style = style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colors.surfaceContainerHighest,
            );
          case 'link':
            final value = (mark['attrs'] as Map?)?['href']?.toString();
            if (value != null && value.isNotEmpty) href = value;
        }
      }
    }
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    if (href != null) return [linkSpan(text, href, _linkStyle(style))];
    return linkify(text, style);
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

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
