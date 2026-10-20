import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable text drafts, one per conversation/thread composer.
///
/// A controller belongs to one widget lifetime. Android may recreate that
/// widget after Home, memory pressure, or an external intent, so it cannot be
/// the draft's owner.
class ComposerDraftStore {
  static const _prefix = 'message_composer_draft.v1.';
  final Map<String, Future<void>> _pendingWrites = {};

  String _segment(String value) => Uri.encodeComponent(value);

  String _conversationPrefix(String ownerId, String conversationId) =>
      '$_prefix${_segment(ownerId)}.${_segment(conversationId)}.';

  String _key(String ownerId, String conversationId, String? parentId) =>
      '${_conversationPrefix(ownerId, conversationId)}'
      '${parentId == null ? 'root' : _segment(parentId)}';

  Future<String> read(
    String ownerId,
    String conversationId, {
    String? parentId,
  }) async {
    if (ownerId.isEmpty) return '';
    final key = _key(ownerId, conversationId, parentId);
    await (_pendingWrites[key] ?? Future<void>.value());
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? '';
  }

  Future<void> write(
    String ownerId,
    String conversationId,
    String text, {
    String? parentId,
  }) async {
    if (ownerId.isEmpty) return;
    final key = _key(ownerId, conversationId, parentId);
    await _serialize(key, (prefs) async {
      await prefs.remove('$key.send');
      if (text.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, text);
      }
    });
  }

  /// Bind only the exact revision submitted. Subsequent edits remove the
  /// binding, even when the user types the same text again.
  Future<void> bindSend(
    String ownerId,
    String conversationId,
    String clientRef,
    String expectedText, {
    String? parentId,
  }) async {
    if (ownerId.isEmpty) return;
    final key = _key(ownerId, conversationId, parentId);
    await _serialize(key, (prefs) async {
      if (prefs.getString(key) == expectedText) {
        await prefs.setString('$key.send', clientRef);
      }
    });
  }

  Future<void> completeSend(
    String ownerId,
    String conversationId,
    String clientRef, {
    String? parentId,
  }) async {
    if (ownerId.isEmpty) return;
    final key = _key(ownerId, conversationId, parentId);
    await _serialize(key, (prefs) async {
      if (prefs.getString('$key.send') != clientRef) return;
      await prefs.remove(key);
      await prefs.remove('$key.send');
    });
  }

  Future<void> _serialize(
    String key,
    Future<void> Function(SharedPreferences) action,
  ) async {
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final write = previous.catchError((Object _) {}).then((_) async {
      await action(await SharedPreferences.getInstance());
    });
    _pendingWrites[key] = write;
    try {
      await write;
    } finally {
      if (identical(_pendingWrites[key], write)) _pendingWrites.remove(key);
    }
  }

  Future<void> clearConversation(String ownerId, String conversationId) async {
    if (ownerId.isEmpty) return;
    await Future.wait(_pendingWrites.values.toList());
    final prefs = await SharedPreferences.getInstance();
    final prefix = _conversationPrefix(ownerId, conversationId);
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }

  /// Every non-empty draft [ownerId] has, one per composer. Read by Home's
  /// Drafts card; a `.send` binding is not a draft and is skipped.
  Future<List<ComposerDraft>> listAll(String ownerId) async {
    if (ownerId.isEmpty) return const [];
    await Future.wait(_pendingWrites.values.toList());
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix${_segment(ownerId)}.';
    final drafts = <ComposerDraft>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final parts = key.substring(prefix.length).split('.');
      if (parts.length != 2) continue;
      final text = prefs.getString(key) ?? '';
      if (text.trim().isEmpty) continue;
      drafts.add(
        ComposerDraft(
          conversationId: Uri.decodeComponent(parts[0]),
          parentId: parts[1] == 'root' ? null : Uri.decodeComponent(parts[1]),
          text: text,
        ),
      );
    }
    return drafts;
  }

  Future<void> clearAll() async {
    await Future.wait(_pendingWrites.values.toList());
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}

/// One composer's unsent text: the main timeline ([parentId] null) or a thread.
class ComposerDraft {
  const ComposerDraft({
    required this.conversationId,
    required this.parentId,
    required this.text,
  });

  final String conversationId;
  final String? parentId;
  final String text;
}

final composerDraftStoreProvider = Provider<ComposerDraftStore>(
  (ref) => ComposerDraftStore(),
);
