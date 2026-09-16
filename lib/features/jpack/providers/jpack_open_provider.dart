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
}

class JPackOpenState {
  const JPackOpenState({
    this.phase = JPackOpenPhase.loading,
    this.celebrate = false,
  });

  final JPackOpenPhase phase;

  /// True only for the open that just happened — confetti plays once, never
  /// on a revisit.
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
    final opened = await ref
        .read(jpackOpenedStoreProvider)
        .isOpened(args.payload.id);
    if (_disposed) return;
    final status = jpackStatus(isOwn: args.isOwn, opened: opened);
    state = JPackOpenState(
      phase: status == JPackStatus.unopened
          ? JPackOpenPhase.sealed
          : JPackOpenPhase.revealed,
    );
  }

  /// The swipe finished.
  Future<void> open() async {
    if (state.phase != JPackOpenPhase.sealed) return;
    final id = arg.payload.id;
    // Mark before the screen changes, so leaving mid-animation still counts.
    await ref.read(jpackOpenedStoreProvider).markOpened(id);
    if (_disposed) return;
    ref.invalidate(jpackOpenedProvider(id));
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
