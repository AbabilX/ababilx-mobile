import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/onboarding/onboarding_page.dart';
import 'profile_setup_flow.dart';

/// The frame of one profile step: heading, the field, and a foot with the
/// progress dots, an optional Skip and Next.
class ProfileSetupStep extends ConsumerWidget {
  const ProfileSetupStep({
    super.key,
    required this.step,
    required this.titleKey,
    required this.bodyKey,
    required this.field,
    required this.busy,
    required this.onNext,
    this.onSkip,
  });

  final int step;
  final String titleKey;
  final String bodyKey;
  final Widget field;
  final bool busy;

  /// Null while the field cannot be saved.
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final last = step == ProfileSetupFlow.steps - 1;
    return OnboardingPage(
      title: t(titleKey),
      subtitle: t(bodyKey),
      gap: 32,
      bottom: Row(
        children: [
          for (var i = 0; i < ProfileSetupFlow.steps; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == step ? colors.primary : colors.outlineVariant,
              ),
            ),
          const Spacer(),
          if (onSkip != null) ...[
            TextButton(
              onPressed: busy ? null : onSkip,
              child: Text(t('profile_setup_skip')),
            ),
            const SizedBox(width: 24),
          ],
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 48),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            onPressed: busy ? null : onNext,
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t(last ? 'profile_setup_done' : 'profile_setup_next')),
          ),
        ],
      ),
      children: [field],
    );
  }
}
