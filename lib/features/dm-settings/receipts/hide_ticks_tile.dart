import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat-details/details_tile.dart';
import '../../messages/chat_icon.dart';
import 'receipts_hidden_provider.dart';

/// "Hide ticks" on a DM's details screen (server 0159). WhatsApp's rule, and
/// the value line says so: switching yours off also stops theirs. When only
/// the peer switched, the row says that too — otherwise a dark chat with the
/// switch showing "off" reads as a bug.
class HideTicksTile extends ConsumerWidget {
  const HideTicksTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final state = ref.watch(receiptsHiddenProvider(conversationId));
    final value = state.mine
        ? t('dm_hide_ticks_on')
        : state.peerHolds
        ? t('dm_hide_ticks_peer')
        : t('dm_hide_ticks_off');
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedTickDouble02),
      title: t('dm_hide_ticks'),
      value: value,
      onTap: () => _set(context, ref, !state.mine),
      trailing: Switch(
        value: state.mine,
        onChanged: (on) => _set(context, ref, on),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, bool hide) async {
    final failed = AppTranslations.translate(context, ref, 'dm_setting_failed');
    try {
      await ref
          .read(receiptsHiddenOverridesProvider.notifier)
          .set(conversationId, hide);
    } catch (_) {
      if (context.mounted) showAppToast(context, failed, isError: true);
    }
  }
}
