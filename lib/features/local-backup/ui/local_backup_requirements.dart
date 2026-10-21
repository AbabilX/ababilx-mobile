import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settings/settings-hub/settings_row.dart';
import '../data/backup_pin_store.dart';
import '../local_backup_provider.dart';
import 'backup_pin_sheet.dart';

/// Whether this install has a backup PIN; re-read after one is set.
final backupPinSetProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userId = ref.watch(profileProvider.select((p) => p.valueOrNull?.id));
  if (userId == null || userId.isEmpty) return false;
  return ref.read(backupPinStoreProvider).has(userId);
});

/// The one thing a backup waits for: a backup PIN (what opens the file).
/// No email needed. A PIN once set is final for now.
class LocalBackupRequirements extends ConsumerWidget {
  const LocalBackupRequirements({super.key});

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final pin = await showBackupPinSheet(context, confirm: true);
    if (pin == null || !context.mounted) return;
    final userId = ref.read(profileProvider).valueOrNull?.id ?? '';
    if (userId.isEmpty) return;
    await ref.read(backupPinStoreProvider).setPin(userId, pin);
    ref.invalidate(backupPinSetProvider);
    if (!context.mounted) return;
    showAppToast(context, t('backup_pin_saved'));
    // The run that was waiting on the PIN goes now.
    await ref.read(localBackupProvider.notifier).backUpNow();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final pinSet = ref.watch(backupPinSetProvider).valueOrNull ?? false;
    return SettingsRow(
      icon: HugeIcons.strokeRoundedSquareLock02,
      title: t('local_backup_req_pin'),
      subtitle: t(
        pinSet ? 'local_backup_req_pin_set' : 'local_backup_req_pin_body',
      ),
      value: pinSet ? null : t('local_backup_req_missing'),
      onTap: pinSet ? null : () => _setPin(context, ref),
    );
  }
}
