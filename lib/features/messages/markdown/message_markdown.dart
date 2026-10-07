import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/app_toast.dart';
import '../tiptap_autolink.dart';
import '../tiptap_inline.dart';
import 'link_disguise.dart';
import 'tiptap_markdown.dart';

/// A chat body drawn inside a bubble by gpt_markdown (see [markdownOfBody]):
/// emphasis, headings, lists, task lists, quotes and alerts, tables, fenced
/// code, `\(maths\)`, bare links and emails.
///
/// Three things are ours rather than the package's. A mention arrives as a
/// link on [mentionLinkScheme] and opens the person. A phone number dials. And
/// `![](url)` is never fetched: the address was written by whoever sent the
/// message, so loading it would tell their server this phone's IP and the
/// moment the chat was opened — it is drawn as a link to tap instead.
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
    this.onMentionTap,
  });

  final void Function(String userId, String label)? onMentionTap;

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
        onLinkTap: (url, label) => _onLink(context, url, label),
        inlineLinkBuilder: (link) => link.url.startsWith(mentionLinkScheme)
            ? link.defaultSpan(
                children: [
                  TextSpan(
                    text: link.label,
                    style: link.style.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              )
            : link.defaultSpan(),
        inlinePatterns: [
          InlinePattern(
            pattern: phoneCandidatePattern,
            builder: (_, match, style) => _phone(match.group(0)!, style, link),
          ),
        ],
        imageBuilder: (_, url, _, _) => GestureDetector(
          onTap: () => _open(url),
          child: Text(
            url,
            style: style.copyWith(
              color: link,
              decoration: TextDecoration.underline,
              decorationColor: link,
            ),
          ),
        ),
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

  void _onLink(BuildContext context, String url, String label) {
    if (!url.startsWith(mentionLinkScheme)) {
      // Text that reads as one site over a link to another: say where it
      // really goes, and open it only on a second, informed tap.
      final real = disguisedLinkHost(label, url);
      if (real == null) {
        _open(url);
      } else {
        showAppToast(
          context,
          'This link opens $real',
          isError: true,
          actionLabel: 'Open',
          onAction: () => _open(url),
        );
      }
      return;
    }
    final id = Uri.decodeComponent(url.substring(mentionLinkScheme.length));
    final name = label.startsWith('@') ? label.substring(1) : label;
    onMentionTap?.call(id, name);
  }

  /// A digit run that passes the dialable check opens the dialer; anything
  /// else the pattern caught (an order number, a date) stays plain text.
  InlineSpan _phone(String raw, TextStyle style, Color link) {
    if (!isDialablePhone(raw)) return TextSpan(text: raw, style: style);
    return TextSpan(
      text: raw,
      style: style.copyWith(
        color: link,
        decoration: TextDecoration.underline,
        decorationColor: link.withValues(alpha: 0.45),
      ),
      recognizer: TapGestureRecognizer()..onTap = () => _open(phoneHref(raw)),
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
