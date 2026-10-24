import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/themed_illustration.dart';
import '../../local_share/widgets/qr_scan_sheet.dart';
import '../wire/transfer_chats_payload.dart';
import 'transfer_chats_copy.dart';
import 'transfer_send_sheet.dart';

/// Settings → Account → Transfer chats: the OLD phone's side, Signal's
/// "Transfer account" place. Says what the new device shows and where, then
/// scans that code with a camera that says what it is looking for. Only a
/// Transfer chats code is taken here; the general scanner still reads one too.
class TransferChatsScreen extends ConsumerWidget {
  const TransferChatsScreen({super.key});

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final raw = await QrScanSheet.show(
      context,
      title: transferText(ref, 'scan_title'),
      hint: transferText(ref, 'scan_hint'),
    );
    if (raw == null || !context.mounted) return;
    if (!isTransferChatsPayload(raw)) {
      showAppToast(
        context,
        transferText(ref, 'error_not_transfer'),
        isError: true,
      );
      return;
    }
    await showTransferSendSheet(context, ref, raw);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String t(String key) => transferText(ref, key);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget step(int n, String key) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              '$n',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(t(key), style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const ThemedIllustration('assets/images/transfer_chats.svg'),
          const SizedBox(height: 16),
          Text(t('screen_body'), style: muted, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          step(1, 'step_new'),
          step(2, 'step_wifi'),
          step(3, 'step_scan'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _scan(context, ref),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedQrCode,
              size: 20,
              color: theme.colorScheme.onPrimary,
            ),
            label: Text(t('scan_button')),
          ),
          const SizedBox(height: 16),
          Text(t('encrypted_note'), style: muted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
