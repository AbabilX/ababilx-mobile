import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../attachments/storage/storage_providers.dart';
import '../settings-hub/settings_row.dart';
import '../settings-hub/settings_section_header.dart';
import 'storage_age_dialog.dart';
import 'storage_chat_list.dart';
import 'storage_confirm.dart';
import 'storage_usage_bar.dart';

/// Settings → Data and storage → Manage storage.
///
/// What is on this phone, which chats it belongs to, and two ways to get rid
/// of it. Clearing never deletes a message: the attachment goes back to
/// showing a download badge, so nothing is lost that a tap cannot fetch again.
class StorageManagementScreen extends ConsumerWidget {
  const StorageManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const Text('Manage storage'),
      ),
      body: SafeArea(
        top: false,
        child: usage.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Could not read local storage')),
          data: (data) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              StorageUsageBar(usage: data),
              const Divider(height: 8),
              SettingsRow(
                icon: HugeIcons.strokeRoundedSearchList01,
                title: 'Review storage',
                subtitle: 'Largest files first, delete what you pick',
                onTap: () => context.push('/settings/storage/review'),
              ),
              const Divider(height: 24),
              const SettingsSectionHeader('Chats'),
              const StorageChatList(),
              const Divider(height: 24),
              SettingsRow(
                icon: HugeIcons.strokeRoundedCalendarRemove01,
                title: 'Delete older media',
                subtitle: 'Clear everything downloaded before a date',
                onTap: data.isEmpty ? null : () => _deleteOlder(context, ref),
              ),
              SettingsRow(
                icon: HugeIcons.strokeRoundedDelete02,
                title: 'Delete all downloaded media',
                subtitle: 'Messages stay — media can be downloaded again',
                destructive: true,
                onTap: data.isEmpty
                    ? null
                    : () => _deleteAll(context, ref, data.total),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteOlder(BuildContext context, WidgetRef ref) async {
    final age = await showStorageAgeDialog(context);
    if (age == null || !context.mounted) return;
    final confirmed = await confirmStorageDelete(
      context,
      title: age.label.replaceFirst('Older', 'Delete media older'),
      body:
          'Your messages are not deleted — anything still on the server can be '
          'downloaded again.',
    );
    if (!confirmed) return;
    final freed = await ref
        .read(storageManagerProvider)
        .releaseOlderThan(age.cutoff());
    invalidateStorage(ref);
    if (!context.mounted) return;
    showAppToast(context, 'Freed ${formatBytes(freed)}');
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int bytes,
  ) async {
    final confirmed = await confirmStorageDelete(
      context,
      title: 'Delete all downloaded media?',
      body:
          'Frees about ${formatBytes(bytes)}. Your messages are not deleted — '
          'anything still on the server can be downloaded again.',
    );
    if (!confirmed) return;
    final freed = await ref.read(storageManagerProvider).releaseAll();
    invalidateStorage(ref);
    if (!context.mounted) return;
    showAppToast(context, 'Freed ${formatBytes(freed)}');
  }
}
