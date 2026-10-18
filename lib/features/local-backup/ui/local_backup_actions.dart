import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../local_backup_provider.dart';
import 'local_backup_option_sheets.dart';

/// What the switch and the folder row on the Local backup screen do.
class LocalBackupActions {
  LocalBackupActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  LocalBackupNotifier get _notifier => ref.read(localBackupProvider.notifier);
  String _t(String key) => AppTranslations.translate(context, ref, key);

  void _toast(String? error, {String done = 'local_backup_done'}) {
    if (!context.mounted || error == 'local_backup_error_cancelled') return;
    showAppToast(context, _t(error ?? done), isError: error != null);
  }

  /// On: nothing to pick, the first backup starts at once. Off: a picked
  /// folder keeps its files; for the automatic folder the person says
  /// whether the copy on the phone goes too.
  Future<void> toggle(bool on) async {
    if (on) {
      await _notifier.setEnabled(true);
      return _toast(await _notifier.backUpNow());
    }
    if (ref.read(localBackupProvider).settings.hasFolder) {
      await _notifier.disable();
      return _toast(null, done: 'local_backup_turned_off');
    }
    final choice = await pickBackupOffChoice(context, ref);
    if (choice == null) return;
    await _notifier.disable(deleteAutomatic: choice == BackupOffChoice.delete);
    _toast(
      null,
      done: choice == BackupOffChoice.delete
          ? 'local_backup_turned_off_deleted'
          : 'local_backup_turned_off',
    );
  }

  /// The automatic folder keeps every week nothing touched, so the toast says
  /// what this run added rather than implying it copied everything again.
  Future<void> backUpNow() async {
    final error = await _notifier.backUpNow();
    final sealed = _notifier.lastSealed;
    if (error != null || sealed == null) return _toast(error);
    if (!context.mounted) return;
    showAppToast(
      context,
      sealed == 0
          ? _t('local_backup_done_unchanged')
          : _t('local_backup_done_new').replaceAll('{n}', '$sealed'),
    );
  }

  Future<void> changeFolder() async {
    final choice = await pickBackupFolderChoice(context, ref);
    if (choice == null) return;
    if (choice == BackupFolderChoice.phone) {
      return _notifier.useAutomaticFolder();
    }
    final error = await _notifier.changeFolder();
    if (error != null) _toast(error);
  }
}
