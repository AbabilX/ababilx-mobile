import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/chat_conversation.dart';
import 'dm_roster_pins.dart';

// The vault's part files reach these through this one import.
export 'dm_roster_pins.dart';
export 'group_roster_pins.dart';
export 'sealed_since.dart';

/// Thrown when a send into a conversation this phone knows as encrypted would
/// have gone out readable. A [StateError], so every place that already shows
/// one keeps doing so.
class ChatEncryptionDowngrade extends StateError {
  ChatEncryptionDowngrade()
    : super('Not sent: this chat is encrypted and the message could not be');
}

/// Whether a message into [conversation] has to be sealed.
///
/// What the server says about the conversation is only half of it: a chat
/// this phone has [pinned] as encrypted stays one whatever the list says now.
bool mustSealChat({
  required bool pinned,
  required ChatConversation? conversation,
}) => pinned || (conversation?.isEncrypted ?? false);

/// Whether a send that cannot be sealed yet may go out as it is: only a group
/// the server marks `plaintext_until_keyed` that this phone has never seen
/// encrypted. Once pinned, that flag is no longer believed.
bool mayStayPlaintext({
  required bool pinned,
  required ChatConversation? conversation,
}) => !pinned && (conversation?.plaintextUntilKeyed ?? false);

/// Whether the list shows [conversation] as encrypted right now, with no
/// plaintext exception. Seeing this once is what pins it.
bool showsAsSealed(ChatConversation conversation) =>
    conversation.isEncrypted && !conversation.plaintextUntilKeyed;

/// This phone's own memory of which conversations are encrypted.
///
/// Whether to seal used to be asked of the server on every send: the
/// conversation's type, the `plaintext_until_keyed` flag and the
/// `encrypted_attachments` switch all arrive from it. A server that changed
/// any of the three got the next message in the clear, with no error on the
/// phone. So the first answer is remembered and a later one can only add:
/// a pinned conversation is never sent to unsealed, and an account that was
/// once told to encrypt its files keeps doing it.
///
/// Trust on first use, like the safety-number store: a conversation first met
/// under a lying server is not protected, and a fresh install has pinned
/// nothing. Ids are not secret, so this is ordinary SharedPreferences, which
/// the notification isolate can read too. Kept across sign-out: the rows are
/// per account and say only "sealed".
class EncryptionPins {
  const EncryptionPins();

  static const _chats = 'chat_sealed_conversations_v1:';
  static const _uploads = 'chat_sealed_uploads_v1:';
  static final _memory = <String, Set<String>>{};
  // Accounts whose pins were really read from disk. Until then every call
  // tries again, and nothing held only in memory is written over the file.
  static final _read = <String>{};

  Future<Set<String>> _load(String userId, {bool reload = false}) async {
    final held = _memory[userId];
    if (held != null && !reload && _read.contains(userId)) return held;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another isolate may have written since this one last looked.
      if (reload) await prefs.reload();
      final pins = {...?held, ...?prefs.getStringList('$_chats$userId')};
      _read.add(userId);
      return _memory[userId] = pins;
    } catch (_) {
      // Storage that cannot be read is not the server's doing. The send goes
      // on under the list's answer, and the next read tries again.
      return _memory[userId] = held ?? <String>{};
    }
  }

  /// Pass [reload] from an isolate that does not write pins itself.
  Future<bool> isPinned(
    String userId,
    String conversationId, {
    bool reload = false,
  }) async {
    if (userId.isEmpty || conversationId.isEmpty) return false;
    return (await _load(userId, reload: reload)).contains(conversationId);
  }

  /// The pinned ones among [conversationIds].
  Future<Set<String>> pinnedAmong(
    String userId,
    Iterable<String> conversationIds,
  ) async {
    if (userId.isEmpty) return const {};
    final pins = await _load(userId);
    return {
      for (final id in conversationIds)
        if (pins.contains(id)) id,
    };
  }

  Future<void> pin(String userId, Iterable<String> conversationIds) async {
    if (userId.isEmpty) return;
    final pins = await _load(userId);
    final before = pins.length;
    pins.addAll(conversationIds.where((id) => id.isNotEmpty));
    if (pins.length == before) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_chats$userId';
      // Added to what is stored, never in place of it: a pin is not removed,
      // and a read that failed earlier must not shrink the file now.
      pins.addAll(prefs.getStringList(key) ?? const []);
      await prefs.setStringList(key, pins.toList());
    } catch (_) {
      // Held in memory for this run; written with the next pin.
    }
  }

  /// Pins every conversation a fetched list shows as encrypted, and who each
  /// DM in it is with.
  Future<void> observe(
    String userId,
    Iterable<ChatConversation> conversations,
  ) async {
    await const DmRosterPins().observe(userId, conversations);
    await pin(userId, [
      for (final c in conversations)
        if (showsAsSealed(c)) c.id,
    ]);
  }

  /// Whether this account's uploads are encrypted: what the server says now
  /// ([enabled]), or what it said once.
  Future<bool> sealsUploads(String userId, {required bool enabled}) async {
    if (userId.isEmpty) return enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_uploads$userId';
      if (enabled) {
        if (prefs.getBool(key) != true) await prefs.setBool(key, true);
        return true;
      }
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return enabled;
    }
  }
}

final encryptionPinsProvider = Provider<EncryptionPins>(
  (ref) => const EncryptionPins(),
);
