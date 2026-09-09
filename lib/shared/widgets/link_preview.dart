import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../link-preview/link_preview_builder.dart';
import '../link-preview/link_preview_photo.dart';
import '../link-preview/link_safety.dart';

/// Extract http(s) URLs from plain text, in the order they were written.
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

/// The wall's card: a bordered panel on the post surface, not the flush
/// in-bubble card chat draws (`chat-timeline/message_link_preview.dart`). Both
/// read the same on-device unfurl.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LinkPreviewBuilder(
      url: url,
      builder: (context, preview) {
        // No card at all while it loads and none if it never arrives. A
        // skeleton on a page of posts is more movement than the card is worth,
        // and a login wall or a tagless page is not an error worth drawing.
        if (preview == null) return const SizedBox.shrink();
        final title = preview.title;
        final description = preview.description;
        final image = preview.imagePath;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (preview.siteName ?? previewDomain(url))
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (title != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (description != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
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
                      if (image != null)
                        SizedBox(
                          width: 116,
                          child: LinkPreviewPhoto(
                            path: image,
                            fallback: ColoredBox(
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Up to three cards under a wall post or comment. Chat draws its own, one per
/// message, inside the bubble.
class MessageLinkPreviews extends StatelessWidget {
  const MessageLinkPreviews({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final urls = extractUrls(text).where(isValidPreviewUrl).toList();
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final url in urls) LinkPreviewCard(url: url)],
    );
  }
}
