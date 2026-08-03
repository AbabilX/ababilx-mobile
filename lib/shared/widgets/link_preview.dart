import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Extract http(s) URLs from plain text (web `extractUrls` parity, max 3).
List<String> extractUrls(String text, {int max = 3}) {
  final found = <String>{};
  final re = RegExp(r'https?:\/\/[^\s<>\[\]()"]+', caseSensitive: false);
  for (final m in re.allMatches(text)) {
    var url = m.group(0)!;
    final suffix = RegExp(r'[.,;!?)]+$').firstMatch(url);
    if (suffix != null) {
      url = url.substring(0, url.length - suffix.group(0)!.length);
    }
    if (url.isNotEmpty) found.add(url);
    if (found.length >= max) break;
  }
  return found.toList();
}

/// Web parity ([LinkPreview] via microlink.io).
class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  _LinkMeta? _meta;
  bool _loading = true;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _meta = null;
      _loading = true;
      _gone = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final res = await Dio().get<Map<String, dynamic>>(
        'https://api.microlink.io',
        queryParameters: {'url': widget.url},
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final body = res.data;
      if (!mounted) return;
      if (body == null || body['status'] != 'success') {
        setState(() {
          _loading = false;
          _gone = true;
        });
        return;
      }
      final data = body['data'];
      if (data is! Map) {
        setState(() {
          _loading = false;
          _gone = true;
        });
        return;
      }
      final title = data['title'] as String?;
      if (title == null || title.isEmpty) {
        setState(() {
          _loading = false;
          _gone = true;
        });
        return;
      }
      final image = data['image'];
      final logo = data['logo'];
      setState(() {
        _meta = _LinkMeta(
          title: title,
          description: data['description'] as String?,
          siteName: data['publisher'] as String?,
          imageUrl: image is Map ? image['url'] as String? : null,
          logoUrl: logo is Map ? logo['url'] as String? : null,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _gone = true;
      });
    }
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String get _host {
    try {
      return Uri.parse(widget.url).host;
    } catch (_) {
      return widget.url;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: 80,
                      color: scheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: double.infinity,
                      color: scheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final meta = _meta;
    if (meta == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (meta.logoUrl != null) ...[
                                CachedNetworkImage(
                                  imageUrl: meta.logoUrl!,
                                  width: 14,
                                  height: 14,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  (meta.siteName ?? _host).toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meta.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (meta.description != null &&
                              meta.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              meta.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (meta.imageUrl != null)
                    SizedBox(
                      width: 116,
                      child: CachedNetworkImage(
                        imageUrl: meta.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Body text with http(s) URLs rendered as tappable, underlined links.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final scheme = Theme.of(context).colorScheme;
    final base =
        widget.style ??
        DefaultTextStyle.of(context).style.copyWith(color: scheme.onSurface);
    final linkStyle = base.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );

    final re = RegExp(r'https?:\/\/[^\s<>\[\]()"]+', caseSensitive: false);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in re.allMatches(widget.text)) {
      var end = m.end;
      var url = m.group(0)!;
      final trailing = RegExp(r'[.,;!?)]+$').firstMatch(url);
      if (trailing != null) {
        end -= trailing.group(0)!.length;
        url = url.substring(0, url.length - trailing.group(0)!.length);
      }
      if (url.isEmpty) continue;
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final uri = Uri.tryParse(url);
          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: widget.text.substring(m.start, end),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      last = end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

/// Renders up to 3 link preview cards under message/post body.
class MessageLinkPreviews extends StatelessWidget {
  const MessageLinkPreviews({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final urls = extractUrls(text);
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final url in urls) LinkPreviewCard(url: url)],
    );
  }
}

class _LinkMeta {
  const _LinkMeta({
    required this.title,
    this.description,
    this.siteName,
    this.imageUrl,
    this.logoUrl,
  });

  final String title;
  final String? description;
  final String? siteName;
  final String? imageUrl;
  final String? logoUrl;
}
