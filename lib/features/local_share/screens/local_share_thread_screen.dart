import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubbles/share_bubble.dart';
import '../bubbles/share_cluster.dart';
import '../data/share_thread_queries.dart';
import '../local_share_engine.dart';
import '../providers/local_share_providers.dart';
import '../providers/share_account.dart';
import '../share_text.dart';
import '../sheets/message_actions_sheet.dart';
import '../sheets/thread_menu_sheet.dart';
import '../widgets/share_page_frame.dart';
import '../widgets/share_thread_bottom.dart';
import '../widgets/share_thread_empty.dart';
import '../widgets/share_thread_header.dart';

const _page = 60;

/// One device's thread: everything sent to it and received from it over a
/// local network, kept on this phone only.
class LocalShareThreadScreen extends ConsumerStatefulWidget {
  const LocalShareThreadScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<LocalShareThreadScreen> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<LocalShareThreadScreen> {
  final _scroll = ScrollController();
  int _limit = _page;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Reversed list: the far end is the oldest message.
      if (_scroll.position.extentAfter < 600) {
        final shown = ref
            .read(
              localShareThreadProvider((
                deviceId: widget.deviceId,
                limit: _limit,
              )),
            )
            .valueOrNull
            ?.length;
        if (shown != null && shown >= _limit) setState(() => _limit += _page);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.deviceId;
    final engine = ref.watch(localShareEngineProvider).valueOrNull;
    final device = ref.watch(localShareDeviceProvider(id)).valueOrNull;
    final peer = ref.watch(localSharePeersProvider).valueOrNull?[id];
    final key = (deviceId: id, limit: _limit);
    final bubbles = ref.watch(localShareThreadProvider(key)).valueOrNull;
    final name = peer?.name ?? device?.name ?? '';
    final userId = peer?.userId ?? device?.userId;
    final account = ref.watch(shareAccountProvider(userId));

    // Anything on screen has been seen.
    if (engine != null && (bubbles?.any((b) => b.message.unread) ?? false)) {
      unawaited(engine.queries.markRead(id));
    }

    final status = peer == null
        ? lsText(ref, 'ls_status_away')
        : lsText(ref, 'ls_status_nearby');
    final owner = account == null
        ? null
        : account.mine
        ? lsText(ref, 'ls_your_account')
        : account.name;

    return SharePageFrame(
      header: ShareThreadHeader(
        name: name,
        status: owner == null ? status : '$owner · $status',
        deviceType: peer?.deviceType ?? device?.deviceType ?? 'mobile',
        userId: userId,
        nearby: peer != null,
        menuLabel: lsText(ref, 'chat_more'),
        onMenu: engine == null || device == null
            ? null
            : () async {
                final gone = await showShareThreadMenu(
                  context,
                  ref,
                  engine,
                  device,
                );
                if (gone && context.mounted) Navigator.of(context).maybePop();
              },
      ),
      body: Column(
        children: [
          Expanded(
            child: bubbles == null || bubbles.isEmpty
                ? const ShareThreadEmpty()
                : _list(engine, bubbles),
          ),
          if (engine != null)
            ShareThreadBottom(
              engine: engine,
              peerId: id,
              peer: peer,
              device: device,
            ),
        ],
      ),
    );
  }

  Widget _list(LocalShareEngine? engine, List<ShareBubbleData> bubbles) {
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      itemCount: bubbles.length,
      itemBuilder: (context, i) {
        final data = bubbles[i];
        return ShareBubble(
          key: ValueKey(data.message.id),
          data: data,
          position: shareClusterPosition(
            i + 1 < bubbles.length ? bubbles[i + 1] : null,
            data,
            i > 0 ? bubbles[i - 1] : null,
          ),
          onLongPress: () {
            if (engine != null) {
              unawaited(showShareMessageActions(context, ref, engine, data));
            }
          },
          onRetry: () => unawaited(engine?.sender.retry(data.message.id)),
        );
      },
    );
  }
}
