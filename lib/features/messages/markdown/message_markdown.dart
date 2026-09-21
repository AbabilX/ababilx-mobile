import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tiptap_inline.dart';

/// A markdown chat body drawn inside a bubble (see [markdownSourceOf]).
///
/// Headings are scaled off the bubble's own text size rather than the app's
/// display styles: a `# Title` from a bot is a heading within one message, and
/// the package's default h1 is larger than the chat header.
class MessageMarkdown extends StatelessWidget {
  const MessageMarkdown({
    super.key,
    required this.source,
    required this.style,
    this.trailing,
  });

  final String source;
  final TextStyle style;

  /// Drawn after the body, e.g. the "(edited)" marker. Markdown ends in a
  /// block, so it cannot join the last line the way TipTap's span does.
  final InlineSpan? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = style.fontSize ?? 16;
    TextStyle heading(double scale) => style.copyWith(
      fontSize: size * scale,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
    final link = tiptapLinkColorFor(theme.brightness);
    final data = GptMarkdownThemeData(
      brightness: theme.brightness,
      h1: heading(1.3),
      h2: heading(1.2),
      h3: heading(1.1),
      h4: heading(1),
      h5: heading(1),
      h6: heading(1),
      linkColor: link,
      linkHoverColor: link,
      hrLineColor: (style.color ?? theme.colorScheme.onSurface).withValues(
        alpha: 0.25,
      ),
      hrLineThickness: 1,
      autoAddDividerLineAfterH1: false,
    );
    final body = GptMarkdownTheme(
      gptThemeData: data,
      child: GptMarkdown(
        source,
        style: style,
        isStreaming: false,
        followLinkColor: false,
        onLinkTap: (url, _) => _open(url),
      ),
    );
    final tail = trailing;
    if (tail == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text.rich(tail),
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    var uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    if (!uri.hasScheme) uri = Uri.tryParse('https://${url.trim()}');
    // The link was written by whoever sent the message, so only schemes that
    // open a page, a mailer or a dialer are followed.
    const allowed = {'http', 'https', 'mailto', 'tel'};
    if (uri == null || !allowed.contains(uri.scheme.toLowerCase())) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
