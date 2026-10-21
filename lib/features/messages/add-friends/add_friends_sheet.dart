import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../shared/widgets/app_capsule.dart';
import '../../auth/widgets/qr_login_flow.dart';
import 'add_friends_code.dart';
import 'add_friends_scan.dart';

/// Add new friends: your own link and code to hold up, and a camera to read
/// someone else's — one sheet, two tabs. A scanned code is handed to the
/// same dispatcher the header's scanner uses, after the sheet is gone.
Future<void> showAddFriendsSheet(
  BuildContext context,
  WidgetRef ref, {
  bool scan = false,
}) async {
  // The floating nav pill paints over the shell's navigator, so a sheet
  // raised from the chat list would sit under it.
  final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
  hidden.state = true;
  String? payload;
  try {
    payload = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddFriendsSheet(startOnScan: scan),
    );
  } finally {
    hidden.state = false;
  }
  if (payload == null || !context.mounted) return;
  await QrLoginFlow.handle(context, ref, payload);
}

class _AddFriendsSheet extends ConsumerStatefulWidget {
  const _AddFriendsSheet({required this.startOnScan});

  final bool startOnScan;

  @override
  ConsumerState<_AddFriendsSheet> createState() => _AddFriendsSheetState();
}

class _AddFriendsSheetState extends ConsumerState<_AddFriendsSheet> {
  late bool _scan = widget.startOnScan;

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              t('add_friends_title'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppCapsule(
                  label: t('add_friends_tab_code'),
                  icon: HugeIcons.strokeRoundedQrCode,
                  selected: !_scan,
                  onTap: () => setState(() => _scan = false),
                ),
                const SizedBox(width: 10),
                AppCapsule(
                  label: t('add_friends_tab_scan'),
                  icon: HugeIcons.strokeRoundedCamera01,
                  selected: _scan,
                  onTap: () => setState(() => _scan = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // The camera exists only while its tab is open: switching back
          // to the code releases it.
          Expanded(
            child: _scan
                ? AddFriendsScan(
                    onCode: (code) => Navigator.of(context).pop(code),
                  )
                : const AddFriendsCode(),
          ),
        ],
      ),
    );
  }
}
