import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import 'models/call_log_entry.dart';

/// The newest page of call history, kept on the phone so Talks draws at once
/// (offline too) and the network only refreshes it.
///
/// One slot, stamped with the account that wrote it: a different account's
/// history is never read back, and an account switch deletes it
/// ([AccountDataWiper]). A plain sign-out keeps it, like the chat archive.
class CallLogCache {
  const CallLogCache(this._owner);

  static const key = 'call_log_cache_v1';

  /// The account whose data this phone holds; empty when unknown.
  final Future<String?> Function() _owner;

  Future<CallLogPage?> read() async {
    try {
      final owner = (await _owner())?.trim() ?? '';
      if (owner.isEmpty) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['owner'] != owner) return null;
      return CallLogPage.fromJson(json['page'] as Map<String, dynamic>);
    } catch (_) {
      // A corrupt or old-shaped copy is only a slower first paint.
      return null;
    }
  }

  Future<void> write(CallLogPage page) async {
    try {
      final owner = (await _owner())?.trim() ?? '';
      if (owner.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({'owner': owner, 'page': page.toJson()}),
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

final callLogCacheProvider = Provider<CallLogCache>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return CallLogCache(storage.readLocalDataOwnerUserId);
});
