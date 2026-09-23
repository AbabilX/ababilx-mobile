import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../privacy_mode_provider.dart';
import 'privacy_people_provider.dart';
import 'privacy_person.dart';

/// The three-way choice for one person: follow the switch, always private,
/// never private. Picking one closes the sheet and saves; a refusal is
/// reported on the screen underneath, since the sheet is gone by then.
Future<void> showPrivacyPersonSheet(
  BuildContext context,
  WidgetRef ref, {
  required PrivacyPerson person,
  required String displayName,
}) async {
  final picked = await showModalBottomSheet<PrivacyPersonMode>(
    context: context,
    showDragHandle: true,
    builder: (_) => _PrivacyPersonSheet(
      current: ref.read(privacyPeopleProvider.notifier).modeFor(person.userId),
      displayName: displayName,
    ),
  );
  if (picked == null || !context.mounted) return;
  final failed = AppTranslations.of(
    ref.read(appLanguageProvider),
    'privacy_person_save_failed',
  );
  final ok = await ref
      .read(privacyPeopleProvider.notifier)
      .set(person.withMode(picked));
  if (!ok && context.mounted) showAppToast(context, failed);
}

class _PrivacyPersonSheet extends ConsumerWidget {
  const _PrivacyPersonSheet({required this.current, required this.displayName});

  final PrivacyPersonMode current;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final switchOn = ref.watch(privacyModeProvider);
    final options = [
      (
        PrivacyPersonMode.follow,
        t('privacy_person_follow'),
        t(switchOn ? 'privacy_person_follow_on' : 'privacy_person_follow_off'),
      ),
      (
        PrivacyPersonMode.always,
        t('privacy_person_always'),
        t('privacy_person_always_hint'),
      ),
      (
        PrivacyPersonMode.never,
        t('privacy_person_never'),
        t('privacy_person_never_hint'),
      ),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              t('privacy_person_sheet_title').replaceAll('{name}', displayName),
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final (mode, title, hint) in options)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(title),
              subtitle: Text(hint, style: TextStyle(color: muted)),
              trailing: mode == current
                  ? ChatIcon(
                      HugeIcons.strokeRoundedTick02,
                      color: theme.colorScheme.primary,
                    )
                  : null,
              selected: mode == current,
              onTap: () => Navigator.of(context).pop(mode),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              t('privacy_person_scope'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The value a row states under its title: the choice, or — when following
/// the switch — what the switch currently means for this person.
String privacyPersonValue(
  String Function(String) t,
  PrivacyPersonMode mode, {
  required bool switchOn,
}) => switch (mode) {
  PrivacyPersonMode.always => t('privacy_person_always'),
  PrivacyPersonMode.never => t('privacy_person_never'),
  PrivacyPersonMode.follow => t(
    switchOn ? 'privacy_person_value_on' : 'privacy_person_value_off',
  ),
};
