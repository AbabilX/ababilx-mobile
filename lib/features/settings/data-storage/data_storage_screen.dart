import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/network_class.dart';
import '../../../core/network/network_probe.dart';
import '../../../shared/text/byte_size.dart';
import '../../attachments/attachment_config.dart';
import '../../attachments/auto_download/auto_download_settings.dart';
import '../../attachments/auto_download/auto_download_store.dart';
import '../../attachments/storage/storage_providers.dart';
import '../../../shared/media/media_quality.dart';
import '../settings-hub/settings_row.dart';
import '../settings-hub/settings_section_header.dart';
import 'auto_download_dialog.dart';
import 'background_connection_row.dart';

/// Settings → Data and storage. The reference app's screen of the same name.
///
/// Four questions, in the order they matter: what is already on this phone,
/// what may land on it without being asked, how hard outgoing pictures are
/// squeezed, and whether the OS is letting the app stay reachable at all.
class DataStorageScreen extends ConsumerWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider);
    final autoDownload = ref.watch(autoDownloadSettingsProvider);
    final quality = ref.watch(mediaQualityProvider);
    String t(String key) => AppTranslations.translate(context, ref, key);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const Text('Data and storage'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SettingsSectionHeader('Storage'),
            SettingsRow(
              icon: HugeIcons.strokeRoundedDatabase01,
              title: 'Manage storage',
              subtitle: 'Photos, video and files kept on this phone',
              value: usage.maybeWhen(
                data: (data) => formatBytes(data.total),
                orElse: () => '',
              ),
              onTap: () => context.push('/settings/storage'),
            ),
            // Directly under Manage storage: both answer "what happens to my
            // history", and this is the only one that answers it for a phone
            // that is lost rather than full.
            SettingsRow(
              icon: HugeIcons.strokeRoundedCloudUpload,
              title: t('settings_backup'),
              subtitle: t('settings_backup_sub'),
              onTap: () => context.push('/settings/chat-backup'),
            ),
            SettingsRow(
              icon: HugeIcons.strokeRoundedSquareLock02,
              title: t('chatlock_settings_title'),
              subtitle: t('chatlock_settings_row_sub'),
              onTap: () => context.push('/settings/data-storage/chat-lock'),
            ),
            const Divider(height: 24),
            const SettingsSectionHeader('Media auto-download'),
            for (final media in AutoDownloadMedia.values)
              SettingsRow(
                icon: _icons[media]!,
                title: media.label,
                value: autoDownload.describe(media),
                onTap: () => _edit(context, ref, media),
              ),
            _AutoDownloadFootnote(network: ref.watch(networkClassProvider)),
            const Divider(height: 24),
            const SettingsSectionHeader('Sending'),
            SettingsRow(
              icon: HugeIcons.strokeRoundedImage01,
              title: 'Sent media quality',
              subtitle: 'How much photos are compressed before sending',
              value: quality == MediaQuality.high ? 'High' : 'Standard',
              onTap: () => context.push('/settings/media-quality'),
            ),
            const Divider(height: 24),
            const SettingsSectionHeader('Connection'),
            const BackgroundConnectionRow(),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AutoDownloadMedia media,
  ) async {
    final settings = ref.read(autoDownloadSettingsProvider);
    final picked = await showAutoDownloadDialog(
      context,
      media: media,
      selected: settings.networksFor(media),
    );
    if (picked == null) return;
    await ref
        .read(autoDownloadSettingsProvider.notifier)
        .setNetworks(media, picked);
  }
}

/// Says which of the boxes above is the one in force right now.
///
/// Without it "Wi-Fi, Cellular" is a rule with no visible subject, and the
/// commonest support question — why a photo has not arrived — has no answer on
/// the screen that decides it.
class _AutoDownloadFootnote extends StatelessWidget {
  const _AutoDownloadFootnote({required this.network});

  final AsyncValue<NetworkClass> network;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = network.maybeWhen(data: _describe, orElse: () => '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'Anything larger than ${formatBytes(autoDownloadMaxBytes)} always '
        'waits for a tap, whatever is chosen here.$now',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _describe(NetworkClass network) => switch (network) {
    NetworkClass.wifi => ' You are on Wi-Fi right now.',
    NetworkClass.cellular => ' You are on cellular right now.',
    NetworkClass.roaming => ' You are roaming right now.',
    NetworkClass.offline => ' You are offline right now.',
  };
}

const _icons = {
  AutoDownloadMedia.photos: HugeIcons.strokeRoundedImage01,
  AutoDownloadMedia.audio: HugeIcons.strokeRoundedMic01,
  AutoDownloadMedia.video: HugeIcons.strokeRoundedVideo01,
  AutoDownloadMedia.documents: HugeIcons.strokeRoundedFile01,
};
