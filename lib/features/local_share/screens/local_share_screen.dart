import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../engine/protocol/share_peer.dart';
import '../providers/local_share_providers.dart';
import '../providers/share_account.dart';
import '../providers/share_quick_button.dart';
import '../share_text.dart';
import '../sheets/device_name_sheet.dart';
import '../widgets/share_device_avatar.dart';
import '../../../shared/widgets/flat_capsule_header.dart';
import '../widgets/share_page_frame.dart';
import '../widgets/share_setup_view.dart';
import '../widgets/share_thread_tile.dart';

/// Local Share: the devices around you and the threads you have with them.
class LocalShareScreen extends ConsumerWidget {
  const LocalShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(localShareNameProvider);
    final title = lsText(ref, 'settings_local_share');
    final mine = name.valueOrNull;
    if (mine == null) {
      return SharePageFrame(
        header: FlatCapsuleHeader(title: FlatHeaderLabel(title)),
        body: name.isLoading ? const SizedBox.shrink() : const ShareSetupView(),
      );
    }

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final peers = ref.watch(localSharePeersProvider).valueOrNull ?? const {};
    final threads =
        ref.watch(localShareThreadsProvider).valueOrNull ?? const [];
    final known = {for (final t in threads) t.device.deviceId};
    final strangers = [
      for (final p in peers.values)
        if (!known.contains(p.deviceId)) p,
    ];

    // The app's settings sections: a hairline, then a quiet heading.
    List<Widget> header(String key) => [
      const Divider(height: 24),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(lsText(ref, key), style: theme.textTheme.labelLarge),
      ),
    ];

    return SharePageFrame(
      header: FlatCapsuleHeader(
        title: FlatHeaderLabel(title),
        action: FlatHeaderAction(
          icon: HugeIcons.strokeRoundedRefresh,
          label: lsText(ref, 'ls_refresh'),
          onPressed: () => unawaited(
            ref.read(localShareEngineProvider).valueOrNull?.presence.refresh(),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const ChatIcon(HugeIcons.strokeRoundedSmartPhone01),
            title: Text(mine, style: theme.textTheme.titleSmall),
            subtitle: Text(
              lsText(ref, 'ls_this_device'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            trailing: ChatIcon(
              HugeIcons.strokeRoundedPencilEdit02,
              size: 20,
              color: muted,
            ),
            onTap: () => showDeviceNameSheet(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              lsText(ref, 'ls_same_wifi_note'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(lsText(ref, 'ls_quick_button')),
            subtitle: Text(lsText(ref, 'ls_quick_button_sub')),
            value: ref.watch(shareQuickButtonProvider),
            onChanged: (on) =>
                unawaited(ref.read(shareQuickButtonProvider.notifier).set(on)),
          ),
          ...header('ls_section_nearby'),
          if (strangers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                lsText(
                  ref,
                  peers.isEmpty ? 'ls_searching' : 'ls_no_new_devices',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            )
          else
            for (final peer in strangers) _NearbyTile(peer: peer),
          if (threads.isNotEmpty) ...header('ls_section_threads'),
          for (final thread in threads)
            ShareThreadTile(
              thread: thread,
              nearby: peers.containsKey(thread.device.deviceId),
              onTap: () =>
                  context.push('/local-share/${thread.device.deviceId}'),
            ),
        ],
      ),
    );
  }
}

class _NearbyTile extends ConsumerWidget {
  const _NearbyTile({required this.peer});

  final SharePeer peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(shareAccountProvider(peer.userId));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: ShareDeviceAvatar(
        deviceType: peer.deviceType,
        userId: peer.userId,
        nearby: true,
      ),
      title: Text(peer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        account == null
            ? lsText(ref, 'ls_pair_unknown')
            : account.mine
            ? lsText(ref, 'ls_your_account')
            : account.name,
      ),
      onTap: () => context.push('/local-share/${peer.deviceId}'),
    );
  }
}
