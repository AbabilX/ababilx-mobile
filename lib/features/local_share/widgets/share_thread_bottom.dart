import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../engine/protocol/share_peer.dart';
import '../engine/store/share_records.dart';
import '../local_share_engine.dart';
import '../share_text.dart';
import 'share_composer.dart';

/// What sits under a thread: the composer when the device is in range and
/// trusted, a Connect button when it is in range and not, and a plain line
/// when it is away or blocked — the history above stays readable either way.
class ShareThreadBottom extends ConsumerStatefulWidget {
  const ShareThreadBottom({
    super.key,
    required this.engine,
    required this.peerId,
    required this.peer,
    required this.device,
  });

  final LocalShareEngine engine;
  final String peerId;

  /// Null when the device is not on the network.
  final SharePeer? peer;
  final ShareDeviceRecord? device;

  @override
  ConsumerState<ShareThreadBottom> createState() => _ShareThreadBottomState();
}

class _ShareThreadBottomState extends ConsumerState<ShareThreadBottom> {
  bool _asking = false;

  Future<void> _connect(SharePeer peer) async {
    setState(() => _asking = true);
    final error = await widget.engine.pair(peer);
    if (!mounted) return;
    setState(() => _asking = false);
    if (error != null) {
      showAppToast(
        context,
        lsText(ref, 'ls_pair_error_$error', name: peer.name),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;
    final device = widget.device;
    if (device?.blocked ?? false) return _notice('ls_blocked_notice');
    if (peer == null) return _notice('ls_away_notice');
    if (device?.paired ?? false) {
      return ShareComposer(engine: widget.engine, peerId: widget.peerId);
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lsText(
                ref,
                _asking ? 'ls_pair_waiting' : 'ls_pair_needed',
                name: peer.name,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _asking ? null : () => _connect(peer),
                child: Text(lsText(ref, 'ls_connect')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String key) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            lsText(ref, key),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
