import '../protocol/share_peer.dart';
import '../share_layout.dart';
import '../share_progress.dart';
import '../store/share_store.dart';

/// What the request handlers share. The callbacks are how the app hears about
/// the network; none of them is ever answered for the user.
class ShareServerContext {
  ShareServerContext({
    required this.store,
    required this.layout,
    required this.progress,
    required this.self,
    required this.onPairRequest,
    this.onMessage,
    this.onDeleted,
    this.onPaired,
  });

  final ShareStore store;
  final ShareLayout layout;
  final ShareProgressHub progress;

  /// This device as it describes itself right now (the name can change).
  final SharePeer Function() self;

  /// Asks the user. Must complete false when there is nobody to ask.
  final Future<bool> Function(SharePeer peer) onPairRequest;

  /// A message arrived, or one being received changed state.
  final void Function(String deviceId, String messageId)? onMessage;
  final void Function(String deviceId, String messageId)? onDeleted;
  final void Function(String deviceId)? onPaired;

  /// Device ids with an Accept sheet up.
  final pendingPairs = <String>{};

  /// `message/file` keys with a body being written.
  final activeFiles = <String>{};
}
