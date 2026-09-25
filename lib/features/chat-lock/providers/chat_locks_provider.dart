import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/storage/storage_providers.dart';
import '../../notifications/chat/chat_notification_ids.dart';
import '../../notifications/chat/chat_notification_store.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../data/chat_lock_index.dart';
import '../data/chat_lock_secrets.dart';
import 'chat_lock_session.dart';

/// This phone's locked chats and how each opens. Starts from the index read
/// before the first frame, so a locked chat never flashes in the list.
class ChatLocksNotifier extends Notifier<Map<String, ChatLockMethod>> {
  @override
  Map<String, ChatLockMethod> build() => ChatLockIndex.cached;

  Future<void> lockWithDevice(String conversationId) async {
    await ChatLockSecrets.remove(conversationId);
    await _put(conversationId, ChatLockMethod.device);
  }

  Future<void> lockWithPassword(String conversationId, String password) async {
    await ChatLockSecrets.setPassword(conversationId, password);
    await _put(conversationId, ChatLockMethod.password);
  }

  Future<void> removeLock(String conversationId) async {
    final next = {...state}..remove(conversationId);
    await ChatLockIndex.write(next);
    await ChatLockSecrets.remove(conversationId);
    state = next;
  }

  Future<bool> verifyPassword(String conversationId, String password) =>
      ChatLockSecrets.verify(conversationId, password);

  Future<void> _put(String conversationId, ChatLockMethod method) async {
    final wasLocked = state.containsKey(conversationId);
    final next = {...state, conversationId: method};
    await ChatLockIndex.write(next);
    state = next;
    // Whoever just locked it is looking at it; it closes when they leave.
    ref.read(chatLockSessionProvider.notifier).unlock(conversationId);
    if (!wasLocked) await _onLocked(conversationId);
  }

  /// From now on this chat's files are only ever held in memory, so the
  /// copies already on this phone go, and a tray entry already showing its
  /// text is taken down.
  Future<void> _onLocked(String conversationId) async {
    try {
      await ref.read(storageManagerProvider).purgeConversation(conversationId);
    } catch (_) {
      // Storage > Manage storage can still clear them; the lock stands.
    }
    await ChatNotificationStore.clear(conversationId);
    await ref
        .read(localNotificationsProvider)
        .cancel(chatNotificationId(conversationId));
  }
}

final chatLocksProvider =
    NotifierProvider<ChatLocksNotifier, Map<String, ChatLockMethod>>(
      ChatLocksNotifier.new,
    );

final chatLockMethodProvider = Provider.family<ChatLockMethod?, String>(
  (ref, conversationId) =>
      ref.watch(chatLocksProvider.select((m) => m[conversationId])),
);

final isChatLockedProvider = Provider.family<bool, String>(
  (ref, conversationId) =>
      ref.watch(chatLockMethodProvider(conversationId)) != null,
);
