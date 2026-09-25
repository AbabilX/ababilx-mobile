import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/ram_media_cache.dart';
import '../native/device_auth.dart';

/// Which locked chats are open right now, and whether the locked-chats list
/// is. Memory only: a restarted app starts with everything locked.
///
/// [folderVisible] is who the folder may name: only chats revealed by the
/// unlock that opened it (matching password, or every phone-lock chat). A
/// chat can leave [unlocked] when its screen closes and still stay in the
/// folder until the folder itself closes.
class ChatLockSessionState {
  const ChatLockSessionState({
    this.unlocked = const {},
    this.folderVisible = const {},
    this.folderOpen = false,
  });

  final Set<String> unlocked;
  final Set<String> folderVisible;
  final bool folderOpen;

  bool isOpen(String conversationId) => unlocked.contains(conversationId);
}

/// Opens and closes locked chats for this run of the app.
///
/// A chat locks again when its screen closes, and every chat locks again
/// when the app comes back after [awayLimit] in the background. Not on every
/// trip out: attaching a photo, taking one and answering the phone all leave
/// the app for a moment, and a chat that demanded a fingerprint after each
/// of them would be switched off by the end of the day. A prompt of our own
/// ([DeviceAuth.busy]) never counts as leaving.
class ChatLockSession extends Notifier<ChatLockSessionState> {
  static const awayLimit = Duration(seconds: 30);

  DateTime? _hiddenAt;

  @override
  ChatLockSessionState build() {
    final life = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    ref.onDispose(life.dispose);
    return const ChatLockSessionState();
  }

  void unlock(String conversationId) => unlockAll([conversationId]);

  void unlockAll(Iterable<String> ids) => state = ChatLockSessionState(
    unlocked: {...state.unlocked, ...ids},
    folderVisible: state.folderVisible,
    folderOpen: state.folderOpen,
  );

  void relock(String conversationId) {
    if (!state.unlocked.contains(conversationId)) return;
    _set(
      ChatLockSessionState(
        unlocked: {...state.unlocked}..remove(conversationId),
        folderVisible: state.folderVisible,
        folderOpen: state.folderOpen,
      ),
    );
  }

  /// Opens the locked-chats folder showing only [ids], and unlocks them so a
  /// tap reaches the chat without a second prompt. Password unlocks pass
  /// every chat that accepted that password; phone lock passes every
  /// device-lock chat.
  void openFolderWith(Iterable<String> ids) {
    final visible = ids.toSet();
    state = ChatLockSessionState(
      unlocked: {...state.unlocked, ...visible},
      folderVisible: visible,
      folderOpen: true,
    );
  }

  /// Leaving the list closes everything it opened.
  void closeFolder() => relockAll();

  void relockAll() => _set(const ChatLockSessionState());

  void _set(ChatLockSessionState next) {
    state = next;
    // The last open locked chat took its pictures and files with it.
    if (next.unlocked.isEmpty) RamMediaCache.release();
  }

  void _onHide() {
    if (DeviceAuth.busy) return;
    _hiddenAt ??= DateTime.now();
  }

  void _onShow() {
    final at = _hiddenAt;
    _hiddenAt = null;
    if (at == null || DeviceAuth.busy) return;
    if (DateTime.now().difference(at) >= awayLimit) relockAll();
  }
}

final chatLockSessionProvider =
    NotifierProvider<ChatLockSession, ChatLockSessionState>(
      ChatLockSession.new,
    );
