import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/models/chat_models.dart';
import '../data/khaam_payload.dart';
import '../data/khaam_status.dart';
import 'khaam_providers.dart';

enum KhaamOpenPhase {
  loading,

  /// Foil still on: waiting for the scratch.
  sealed,

  /// Opened just now, or opened before, or ours.
  revealed,
}

class KhaamOpenState {
  const KhaamOpenState({
    this.phase = KhaamOpenPhase.loading,
    this.celebrate = false,
  });

  final KhaamOpenPhase phase;

  /// True only for the open that just happened — confetti plays once, never
  /// on a revisit.
  final bool celebrate;
}

class KhaamOpenArgs {
  const KhaamOpenArgs({
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  final ChatMessage message;
  final KhaamPayload payload;
  final bool isOwn;

  @override
  bool operator ==(Object other) =>
      other is KhaamOpenArgs &&
      other.payload.id == payload.id &&
      other.message.id == message.id &&
      other.isOwn == isOwn;

  @override
  int get hashCode => Object.hash(payload.id, message.id, isOwn);
}

class KhaamOpenNotifier
    extends AutoDisposeFamilyNotifier<KhaamOpenState, KhaamOpenArgs> {
  bool _disposed = false;

  @override
  KhaamOpenState build(KhaamOpenArgs args) {
    // The screen can close while a read is in flight; a write after that
    // would land on a disposed notifier.
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load(args);
    return const KhaamOpenState();
  }

  Future<void> _load(KhaamOpenArgs args) async {
    final ids = await ref.read(khaamOpenedIdsProvider.future);
    final opened = ids.contains(args.payload.id);
    if (_disposed) return;
    final status = khaamStatus(isOwn: args.isOwn, opened: opened);
    state = KhaamOpenState(
      phase: status == KhaamStatus.unopened
          ? KhaamOpenPhase.sealed
          : KhaamOpenPhase.revealed,
    );
  }

  /// Enough foil is gone (or Reveal all was pressed).
  Future<void> open() async {
    if (state.phase != KhaamOpenPhase.sealed) return;
    // Mark before the screen changes, so leaving mid-animation still counts.
    await ref.read(khaamOpenedIdsProvider.notifier).markOpened(arg.payload.id);
    if (_disposed) return;
    state = const KhaamOpenState(
      phase: KhaamOpenPhase.revealed,
      celebrate: true,
    );
  }
}

final khaamOpenProvider = NotifierProvider.autoDispose
    .family<KhaamOpenNotifier, KhaamOpenState, KhaamOpenArgs>(
      KhaamOpenNotifier.new,
    );
