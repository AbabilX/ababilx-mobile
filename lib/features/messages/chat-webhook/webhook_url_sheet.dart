import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/app_toast.dart';

/// The one screen that ever holds a feed's secret URL.
///
/// Nothing stores it — not the server, which keeps only a hash, and not this
/// device. It is passed in, shown, copied, and gone when the sheet closes, so
/// the copy button and the warning are the whole point of the surface.
Future<void> showWebhookUrlSheet(
  BuildContext context, {
  required String url,
  required bool isNew,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => _WebhookUrlSheet(url: url, isNew: isNew),
);

class _WebhookUrlSheet extends StatelessWidget {
  const _WebhookUrlSheet({required this.url, required this.isNew});

  final String url;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNew ? 'Webhook feed created' : 'New webhook URL',
                    style: text.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isNew
                  ? 'Members can read this feed. Only this URL can post to it.'
                  : 'The previous URL stopped working the moment this one was '
                        'made. Update whatever was posting to it.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _UrlBox(url: url),
            const SizedBox(height: 8),
            Text(
              'Copy it now — it is shown once and cannot be read back.',
              style: text.bodySmall?.copyWith(color: colors.error),
            ),
            const SizedBox(height: 16),
            _CurlSample(url: url),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrlBox extends StatelessWidget {
  const _UrlBox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              url,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Copy URL',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) showAppToast(context, 'Webhook URL copied');
            },
          ),
        ],
      ),
    );
  }
}

class _CurlSample extends StatelessWidget {
  const _CurlSample({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sample =
        "curl -X POST '$url' \\\n"
        "  -H 'Content-Type: application/json' \\\n"
        '  -d \'{"message":"Deployment completed"}\'';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          sample,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
