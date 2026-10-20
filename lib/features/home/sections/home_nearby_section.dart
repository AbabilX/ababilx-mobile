import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/engine/protocol/share_peer.dart';
import '../../local_share/providers/local_share_providers.dart';
import '../../local_share/widgets/share_device_avatar.dart';
import '../quick-views/quick_view_summary.dart';
import 'home_section.dart';

/// AbabilX devices on this Wi-Fi right now (Local Share), as capsules. A
/// paired device opens its thread; one not paired yet opens Local Share,
/// where pairing is asked. Nothing nearby, or Local Share not set up: the
/// block is not drawn.
class HomeNearbySection extends ConsumerWidget {
  const HomeNearbySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(localSharePeersProvider).valueOrNull ?? const {};
    if (peers.isEmpty) return const SizedBox.shrink();
    final threads = {
      for (final t
          in ref.watch(localShareThreadsProvider).valueOrNull ??
              const <ShareThread>[])
        t.device.deviceId: t,
    };
    final shown = nearbyDevices(peers.values, threads);
    if (shown.isEmpty) return const SizedBox.shrink();
    return HomeSection(
      title: homeText(context, ref, 'home_nearby'),
      actionLabel: homeText(context, ref, 'home_see_all'),
      onAction: () => context.push('/local-share'),
      child: HomeStrip(
        height: HomeCapsule.heightFor(context),
        children: [
          for (final (peer, thread) in shown)
            HomeCapsule(
              key: ValueKey(peer.deviceId),
              leading: (size) => ShareDeviceAvatar(
                deviceType: peer.deviceType,
                userId: peer.userId,
                size: size,
                nearby: true,
              ),
              label: thread?.device.name ?? peer.name,
              onTap: () => context.push(
                thread == null
                    ? '/local-share'
                    : '/local-share/${peer.deviceId}',
              ),
            ),
        ],
      ),
    );
  }
}

/// Nearby peers with their thread if paired; blocked devices left out.
/// Paired first (they are one tap from a conversation), then by name.
List<(SharePeer, ShareThread?)> nearbyDevices(
  Iterable<SharePeer> peers,
  Map<String, ShareThread> threads,
) {
  final out = [
    for (final p in peers)
      if (threads[p.deviceId]?.device.blocked != true) (p, threads[p.deviceId]),
  ];
  out.sort((a, b) {
    final paired = (a.$2 == null ? 1 : 0).compareTo(b.$2 == null ? 1 : 0);
    return paired != 0 ? paired : a.$1.name.compareTo(b.$1.name);
  });
  return out;
}
