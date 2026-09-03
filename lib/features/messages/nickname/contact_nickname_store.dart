import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_nickname.dart';

/// Nicknames live on the device, like the chat wallpaper.
///
/// Deliberately not synced. A nickname is a private note about someone —
/// "Junayed (landlord)" — and pushing it to the server would mean it could leak
/// back to the person it describes, plus a migration, endpoints and web work
/// for something nobody expects to follow them between devices. Signal keeps
/// its nicknames local for the same reasons.
class ContactNicknameStore {
  const ContactNicknameStore();

  static const String _prefix = 'ababilx_contact_nickname_';

  /// Reads every nickname at once. There are never many, and holding the whole
  /// map means a list row can resolve a name without an async gap that would
  /// paint the raw name first and the nickname a frame later.
  Future<ContactNicknames> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final value = prefs.getString(key)?.trim() ?? '';
      if (value.isEmpty) continue;
      entries[key.substring(_prefix.length)] = value;
    }
    return ContactNicknames(entries);
  }

  /// An empty or null [nickname] clears it, restoring the person's own name.
  Future<void> write(String userId, String? nickname) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$userId';
    final cleaned = nickname?.trim() ?? '';
    if (cleaned.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, cleaned);
  }
}

final contactNicknameStoreProvider = Provider<ContactNicknameStore>(
  (ref) => const ContactNicknameStore(),
);
