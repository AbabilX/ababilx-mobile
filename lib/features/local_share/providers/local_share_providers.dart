import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/device_identity_store.dart';
import '../data/share_thread_queries.dart';
import '../engine/protocol/share_peer.dart';
import '../engine/share_progress.dart';
import '../engine/store/share_records.dart';
import '../local_share_actions.dart';
import '../local_share_engine.dart';
import 'local_share_name.dart';
import 'local_share_net.dart';
import 'share_transfer_watch.dart';

export 'local_share_name.dart';

/// Shows the Accept sheet. Null while there is no screen to show it on — and
/// then a pair request is refused, never answered for the user.
final localSharePairPromptProvider =
    StateProvider<Future<bool> Function(SharePeer peer)?>((ref) => null);

/// Called for every message that arrives (device id, message id).
final localShareIncomingProvider =
    StateProvider<void Function(String deviceId, String messageId)?>(
      (ref) => null,
    );

/// The running engine, or null while signed out or before a device name has
/// been chosen. The name and the privacy switch are read each time this
/// device describes itself, so changing either does not restart anything.
final localShareEngineProvider = FutureProvider<LocalShareEngine?>((ref) async {
  final loggedIn = ref.watch(authProvider).valueOrNull ?? false;
  final userId = ref.watch(profileProvider.select((p) => p.valueOrNull?.id));
  final named = ref.watch(
    localShareNameProvider.select((n) => (n.valueOrNull ?? '').isNotEmpty),
  );
  if (!loggedIn || userId == null || userId.isEmpty || !named) return null;

  final engine = await LocalShareEngine.open(
    userId: userId,
    deviceId: await loadOrCreateDeviceFingerprint(),
    name: () => ref.read(localShareNameProvider).valueOrNull ?? 'AbabilX',
    // Privacy mode: nobody is to find this account, so it is not announced.
    accountId: () => ref.read(privacyModeProvider) ? null : userId,
    askPair: (peer) async {
      final prompt = ref.read(localSharePairPromptProvider);
      return prompt == null ? false : prompt(peer);
    },
    onIncoming: (deviceId, messageId) =>
        ref.read(localShareIncomingProvider)?.call(deviceId, messageId),
  );
  engine.onDeviceNearby = (id) => unawaited(engine.flushDeletes(id));
  final watch = ShareTransferWatch(engine.progress);
  ref.onDispose(() {
    unawaited(watch.dispose());
    unawaited(LocalShareNet.release());
    unawaited(engine.dispose());
  });
  await LocalShareNet.acquire();
  await engine.start();
  return engine;
});

/// AbabilX devices on the network right now, by device id.
final localSharePeersProvider = StreamProvider<Map<String, SharePeer>>((
  ref,
) async* {
  final engine = await ref.watch(localShareEngineProvider.future);
  if (engine == null) {
    yield const {};
    return;
  }
  yield engine.presence.peers;
  yield* engine.presence.changes;
});

final localShareThreadsProvider = StreamProvider<List<ShareThread>>((
  ref,
) async* {
  final engine = await ref.watch(localShareEngineProvider.future);
  if (engine == null) {
    yield const [];
    return;
  }
  yield* engine.queries.watchThreads();
});

final localShareDeviceProvider =
    StreamProvider.family<ShareDeviceRecord?, String>((ref, deviceId) async* {
      final engine = await ref.watch(localShareEngineProvider.future);
      if (engine == null) {
        yield null;
        return;
      }
      yield* engine.queries.watchDevice(deviceId);
    });

/// The newest bubbles of one thread; `limit` grows as the user scrolls up.
final localShareThreadProvider =
    StreamProvider.family<
      List<ShareBubbleData>,
      ({String deviceId, int limit})
    >((ref, key) async* {
      final engine = await ref.watch(localShareEngineProvider.future);
      if (engine == null) {
        yield const [];
        return;
      }
      yield* engine.queries.watchThread(key.deviceId, key.limit);
    });

/// Bytes moved so far for one message; null when nothing is moving.
final localShareProgressProvider =
    StreamProvider.family<ShareProgress?, String>((ref, messageId) async* {
      final engine = await ref.watch(localShareEngineProvider.future);
      if (engine == null) {
        yield null;
        return;
      }
      yield engine.progress.current(messageId);
      yield* engine.progress.stream.where((p) => p.messageId == messageId);
    });
