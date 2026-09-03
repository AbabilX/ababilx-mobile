import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contact_nickname.dart';
import 'contact_nickname_store.dart';

class ContactNicknameNotifier extends Notifier<ContactNicknames> {
  bool _disposed = false;

  @override
  ContactNicknames build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return const ContactNicknames();
  }

  ContactNicknameStore get _store => ref.read(contactNicknameStoreProvider);

  Future<void> _load() async {
    final stored = await _store.readAll();
    if (_disposed) return;
    state = stored;
  }

  /// Sets or clears the nickname for one person. State moves first so the name
  /// changes on screen immediately; the write follows.
  Future<void> setNickname(String userId, String? nickname) async {
    if (userId.isEmpty) return;
    state = state.withNickname(userId, nickname);
    await _store.write(userId, nickname);
  }
}

final contactNicknamesProvider =
    NotifierProvider<ContactNicknameNotifier, ContactNicknames>(
      ContactNicknameNotifier.new,
    );
