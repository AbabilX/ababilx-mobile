import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../engine/protocol/share_peer.dart';
import '../providers/local_share_providers.dart';
import '../providers/share_account.dart';
import '../share_text.dart';
import '../sheets/device_name_sheet.dart';
import '../widgets/share_device_avatar.dart';
import '../widgets/share_setup_view.dart';
import '../widgets/share_thread_tile.dart';

/// Local Share: the devices around you and the threads you have with them.
class LocalShareScreen extends ConsumerWidget {
  const LocalShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(localShareNameProvider);
    final title = Text(lsText(ref, 'settings_local_share'));
    if (name.isLoading) {
      return Scaffold(appBar: AppBar(title: title));
    }
    final mine = name.valueOrNull;
    if (mine == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const ShareSetupView(),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final peers = ref.watch(localSharePeersProvider).valueOrNull ?? const {};
    final threads =
        ref.watch(localShareThreadsProvider).valueOrNull ?? const [];
    final known = {for (final t in threads) t.device.deviceId};
    final strangers = [
      for (final p in peers.values)
        if (!known.contains(p.deviceId)) p,
    ];

    Widget header(String key) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        lsText(ref, key),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: [
          IconButton(
            tooltip: lsText(ref, 'ls_refresh'),
            icon: const ChatIcon(HugeIcons.strokeRoundedRefresh),
            onPressed: () => unawaited(
              ref
                  .read(localShareEngineProvider)
                  .valueOrNull
                  ?.presence
                  .refresh(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedSmartPhone01),
            title: Text(mine),
            subtitle: Text(lsText(ref, 'ls_this_device')),
            trailing: const ChatIcon(
              HugeIcons.strokeRoundedPencilEdit02,
              size: 20,
            ),
            onTap: () => showDeviceNameSheet(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              lsText(ref, 'ls_same_wifi_note'),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
          header('ls_section_nearby'),
          if (strangers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Text(
                lsText(
                  ref,
                  peers.isEmpty ? 'ls_searching' : 'ls_no_new_devices',
                ),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            for (final peer in strangers) _NearbyTile(peer: peer),
          if (threads.isNotEmpty) header('ls_section_threads'),
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
