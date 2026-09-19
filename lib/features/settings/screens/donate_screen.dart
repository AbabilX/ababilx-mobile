import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';

/// Settings → Donate: support the indie build. UI only for now — payment
/// wiring (bKash / link) lands when a destination exists.
class DonateScreen extends ConsumerWidget {
  const DonateScreen({super.key});

  static const _heroAsset = 'assets/images/donate_support_build.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('donate_title')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  _heroAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: ChatIcon(
                        HugeIcons.strokeRoundedFavourite,
                        size: 48,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              t('donate_headline'),
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t('donate_body'),
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => showAppToast(context, t('donate_coming_soon')),
              icon: ChatIcon(
                HugeIcons.strokeRoundedFavourite,
                size: 20,
                color: colors.onPrimary,
              ),
              label: Text(t('donate_cta')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t('donate_footnote'),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
