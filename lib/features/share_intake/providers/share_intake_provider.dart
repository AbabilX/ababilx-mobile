import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/share_intake_channel.dart';
import '../data/shared_payload.dart';

final shareIntakeChannelProvider = Provider<ShareIntakeChannel>(
  (ref) => const ShareIntakeChannel(),
);

/// The share another app just handed us, or null when there is nothing
/// pending.
///
/// Held here rather than passed through the router because a share can arrive
/// before there is anywhere to put it: the app may be cold-starting, or signed
/// out. Whoever is ready first ([ShareIntakeSync]) picks it up and clears it.
class ShareIntakeNotifier extends Notifier<SharedPayload?> {
  StreamSubscription<String>? _sub;
  bool _started = false;

  @override
  SharedPayload? build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _started = false;
    });
    return null;
  }

  ShareIntakeChannel get _channel => ref.read(shareIntakeChannelProvider);

  /// Starts listening. Safe to call repeatedly — only the first call binds.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _sub = _channel.shares().listen(
      _accept,
      // A malformed intent must not take the app down; the user simply sees
      // nothing happen and can share again.
      onError: (Object e) => debugPrint('[share] event stream error: $e'),
    );

    try {
      // The share that cold-started the app never comes through the stream.
      _accept(await _channel.initialShare());
    } catch (e) {
      debugPrint('[share] initial share failed: $e');
    }
  }

  void _accept(String? raw) {
    final open = SharedPayload.openConversationId(raw);
    if (open != null) {
      ref.read(shortcutOpenProvider.notifier).state = open;
      return;
    }
    final handle = SharedPayload.openUserHandle(raw);
    if (handle != null) {
      ref.read(userLinkOpenProvider.notifier).state = handle;
      return;
    }
    final slug = SharedPayload.openGroupSlug(raw);
    if (slug != null) {
      ref.read(groupLinkOpenProvider.notifier).state = slug;
      return;
    }
    final payload = SharedPayload.tryParse(raw);
    if (payload == null) return;
    state = payload;
  }

  /// A share that starts inside the app (forwarding a Local Share file into a
  /// chat). It takes the same road as one from another app's share sheet.
  void offer(SharedPayload payload) => state = payload;

  /// Drops the pending share and tells native to forget it, so a hot restart
  /// does not replay one the user already dealt with.
  void consume() {
    state = null;
    unawaited(
      _channel.clear().catchError((Object e) {
        debugPrint('[share] clear failed: $e');
      }),
    );
  }
}

final shareIntakeProvider =
    NotifierProvider<ShareIntakeNotifier, SharedPayload?>(
      ShareIntakeNotifier.new,
    );

/// A chat a Direct Share shortcut asked to open from the launcher's long-press
/// menu. [ShareIntakeSync] routes to it once signed in, then clears it.
final shortcutOpenProvider = StateProvider<String?>((ref) => null);

/// The handle of a personal message link the app was opened with.
/// [ShareIntakeSync] shows that person once signed in, then clears it.
final userLinkOpenProvider = StateProvider<String?>((ref) => null);

/// The slug of a group's public link the app was opened with.
/// [ShareIntakeSync] shows the join sheet once signed in, then clears it.
final groupLinkOpenProvider = StateProvider<String?>((ref) => null);
