import '../../data/local/chat_message_store.dart';
import '../../data/models/chat_models.dart';

/// Thread roots the history window would leave behind.
///
/// The export sends three months, but a reply sent last week can belong to
/// a thread started half a year ago. Without its root the reply reaches the
/// other device with nothing to hang under, and the server has long let the
/// root go. So the roots of exported replies go too, whatever their age —
/// one message per thread, never the rest of the old thread.
class V2ThreadRoots {
  final Set<String> _sent = {};
  final Set<String> _wanted = {};

  void saw(ChatMessage message) {
    _sent.add(message.id);
    final root = message.parentId;
    if (root != null && root.isNotEmpty) _wanted.add(root);
  }

  /// Roots not exported yet, read from this phone. A deleted or missing one
  /// is skipped: `byId` already applies the deletion markers.
  Future<List<ChatMessage>> missing(ChatMessageStore messages) async {
    final out = <ChatMessage>[];
    for (final id in _wanted.difference(_sent)) {
      final root = await messages.byId(id);
      if (root == null || root.isPending || root.id.isEmpty) continue;
      out.add(root);
    }
    return out;
  }
}
