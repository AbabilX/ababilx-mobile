import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';

/// Personal bKash (Send Money). Digits only — shown formatted in the sheet.
const donateBkashNumber = '01755267077';

String get donateBkashDisplay {
  final n = donateBkashNumber;
  if (n.length == 11) {
    return '${n.substring(0, 5)}-${n.substring(5)}';
  }
  return n;
}

/// Settings → Support AbabilX. Sheet, not a route — same shape as Ghost intro
/// / conversation actions: drag handle, safe area, one primary action.
Future<void> showDonateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const DonateSheet(),
  );
}

class DonateSheet extends ConsumerWidget {
  const DonateSheet({super.key});

  static const _heroAsset = 'assets/images/donate_support_build.png';

  Future<void> _copyNumber(BuildContext context, String toast) async {
    await Clipboard.setData(const ClipboardData(text: donateBkashNumber));
    if (!context.mounted) return;
    showAppToast(context, toast);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(
                  _heroAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: ChatIcon(
                        HugeIcons.strokeRoundedFavourite,
                        size: 40,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t('donate_headline'),
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('donate_body'),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _copyNumber(context, t('donate_copied')),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('donate_bkash_label'),
                              style: text.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              donateBkashDisplay,
                              style: text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t('donate_bkash_hint'),
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: t('donate_copy'),
                        onPressed: () =>
                            _copyNumber(context, t('donate_copied')),
                        icon: ChatIcon(
                          HugeIcons.strokeRoundedCopy01,
                          size: 22,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _copyNumber(context, t('donate_copied')),
              icon: ChatIcon(
                HugeIcons.strokeRoundedCopy01,
                size: 20,
                color: colors.onPrimary,
              ),
              label: Text(t('donate_cta')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('donate_footnote'),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
