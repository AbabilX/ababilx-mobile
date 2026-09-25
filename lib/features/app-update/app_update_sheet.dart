import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_translations.dart';
import '../../shared/widgets/app_toast.dart';
import 'app_update_info.dart';
import 'app_update_notes.dart';
import 'app_update_snooze.dart';
import 'app_update_store.dart';

/// Offers an optional update. Anything but Update — Later, a swipe down, a
/// tap outside — snoozes this build for a day.
Future<void> showAppUpdateSheet(
  BuildContext context,
  AppUpdateInfo info, {
  required String lang,
}) async {
  final update = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AppUpdateSheet(info: info),
  );
  if (update != true) {
    await AppUpdateSnooze.snooze(info.latestBuild);
    return;
  }
  final opened = await openAppStore(info.storeUrl);
  if (!opened && context.mounted) {
    showAppToast(
      context,
      AppTranslations.of(lang, 'app_update_store_failed'),
      isError: true,
    );
  }
}

class _AppUpdateSheet extends ConsumerWidget {
  const _AppUpdateSheet({required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    final maxNotes = MediaQuery.sizeOf(context).height * 0.4;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('app_update_title_optional'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'app_update_body_optional',
              ).replaceAll('{version}', info.latestVersion),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (info.whatsNew.isNotEmpty) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxNotes),
                child: SingleChildScrollView(
                  child: AppUpdateNotes(
                    title: t('app_update_whats_new'),
                    notes: info.whatsNew,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(t('app_update_later')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(t('app_update_action')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
