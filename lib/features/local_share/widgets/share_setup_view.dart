import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../share_text.dart';
import '../sheets/device_name_sheet.dart';

/// What Local Share is, shown until this device has a name. Nothing is
/// announced on the network before the user gets past this.
class ShareSetupView extends ConsumerWidget {
  const ShareSetupView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    Widget point(List<List<dynamic>> icon, String key) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatIcon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(lsText(ref, key), style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lsText(ref, 'ls_setup_title'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              lsText(ref, 'ls_setup_body'),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 26),
            point(HugeIcons.strokeRoundedWifi01, 'ls_setup_point_wifi'),
            point(HugeIcons.strokeRoundedFolderTransfer, 'ls_setup_point_size'),
            point(HugeIcons.strokeRoundedSmartPhone01, 'ls_setup_point_local'),
            point(HugeIcons.strokeRoundedAlert02, 'ls_setup_point_plain'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => showDeviceNameSheet(context),
                child: Text(lsText(ref, 'ls_setup_cta')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
