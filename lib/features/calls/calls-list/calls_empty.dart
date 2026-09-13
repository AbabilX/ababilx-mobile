import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';

/// Nothing to show yet — or the first page failed. Both land here, because an
/// empty history and an unreachable server look identical to the user until
/// the message says otherwise.
///
/// The empty half carries a button, the failed half does not. A first-run
/// screen that only says "no calls yet" leaves the one thing to do on another
/// tab; a failed one has nothing to offer but the pull-to-refresh already
/// under it, and a call button there would just fail again.
class CallsEmpty extends StatelessWidget {
  const CallsEmpty({
    super.key,
    this.error,
    this.onStart,
    this.missedOnly = false,
    this.lang = 'en',
  });

  final String? error;

  /// Opens the place a call is started from — the conversation list. Null
  /// hides the button, so the widget stays usable without a router.
  final VoidCallback? onStart;

  /// The history exists, but the active Missed filter has no matches.
  final bool missedOnly;

  final String lang;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final failed = error != null;
    String t(String key) => AppTranslations.of(lang, key);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed
                  ? Icons.cloud_off_rounded
                  : missedOnly
                  ? Icons.phone_in_talk_rounded
                  : Icons.call_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              t(
                failed
                    ? 'calls_error_title'
                    : missedOnly
                    ? 'calls_no_missed_title'
                    : 'calls_empty_title',
              ),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                failed
                    ? 'calls_error_body'
                    : missedOnly
                    ? 'calls_no_missed_body'
                    : 'calls_empty_body',
              ),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            // Debug builds print what actually came back. "Call history
            // unavailable" is the same sentence for a dead socket, a 500 and
            // a parse failure, which is fine for a user and useless while
            // diagnosing one. Never shown in release, so never translated.
            if (failed && kDebugMode) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            if (!failed && !missedOnly && onStart != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(t('calls_empty_action')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
