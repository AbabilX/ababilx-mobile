import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/models/chat_models.dart';
import '../data/jpack_payload.dart';
import '../data/jpack_status.dart';
import 'jpack_providers.dart';

enum JPackOpenPhase {
  loading,

  /// Waiting for the swipe.
  sealed,

  /// Opened just now, or opened before, or ours.
  revealed,

  /// Nobody may open it any more.
  expired,
}

class JPackOpenState {
  const JPackOpenState({
    this.phase = JPackOpenPhase.loading,
    this.celebrate = false,
  });

  final JPackOpenPhase phase;

  /// True only for the open that just credited — confetti and the count-up
  /// play once, never on a revisit.
  final bool celebrate;
}

class JPackOpenArgs {
  const JPackOpenArgs({
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  final ChatMessage message;
  final JPackPayload payload;
  final bool isOwn;

  @override
  bool operator ==(Object other) =>
      other is JPackOpenArgs &&
      other.payload.id == payload.id &&
      other.message.id == message.id &&
      other.isOwn == isOwn;

  @override
  int get hashCode => Object.hash(payload.id, message.id, isOwn);
}

class JPackOpenNotifier
    extends AutoDisposeFamilyNotifier<JPackOpenState, JPackOpenArgs> {
  bool _disposed = false;

  @override
  JPackOpenState build(JPackOpenArgs args) {
    // The screen can close while a read is in flight; a write after that
    // would land on a disposed notifier.
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load(args);
    return const JPackOpenState();
  }

  Future<void> _load(JPackOpenArgs args) async {
    final claimed = await ref
        .read(jpackClaimsStoreProvider)
        .isClaimed(args.payload.id);
    if (_disposed) return;
    final status = jpackStatus(
      isOwn: args.isOwn,
      claimed: claimed,
      expired: jpackIsExpired(args.message),
    );
    state = JPackOpenState(
      phase: switch (status) {
        JPackStatus.claimable => JPackOpenPhase.sealed,
        JPackStatus.opened || JPackStatus.sent => JPackOpenPhase.revealed,
        JPackStatus.expired ||
        JPackStatus.claimClosed => JPackOpenPhase.expired,
      },
    );
  }

  /// The swipe finished. Expiry is checked again here: the envelope may have
  /// sat on screen across the 48-hour mark.
  Future<void> claim() async {
    if (state.phase != JPackOpenPhase.sealed) return;
    final args = arg;
    if (jpackIsExpired(args.message)) {
      state = const JPackOpenState(phase: JPackOpenPhase.expired);
      return;
    }
    final p = args.payload;
    // Credit and mark before the screen changes, so leaving mid-animation
    // cannot lose the money or pay it again on the next tap.
    await ref.read(walletBalanceProvider.notifier).credit(p.amount, ref: p.id);
    await ref.read(jpackClaimsStoreProvider).markClaimed(p.id);
    if (_disposed) return;
    ref.invalidate(jpackClaimedProvider(p.id));
    state = const JPackOpenState(
      phase: JPackOpenPhase.revealed,
      celebrate: true,
    );
  }
}

final jpackOpenProvider = NotifierProvider.autoDispose
    .family<JPackOpenNotifier, JPackOpenState, JPackOpenArgs>(
      JPackOpenNotifier.new,
    );
