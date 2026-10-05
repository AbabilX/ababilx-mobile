import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/protocol/share_peer.dart';

const _key = 'local_share_device_name_v1';

/// The name this DEVICE goes by on a local network. It is the user's own
/// choice and separate from the account's display name: one account's phone
/// and laptop need telling apart. Null until it has been set — and until it
/// is, Local Share neither announces nor listens.
class LocalShareNameNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return cleanShareName(prefs.getString(_key));
  }

  /// False when nothing readable is left of [raw].
  Future<bool> save(String raw) async {
    final name = cleanShareName(raw);
    if (name == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
    state = AsyncData(name);
    return true;
  }
}

final localShareNameProvider =
    AsyncNotifierProvider<LocalShareNameNotifier, String?>(
      LocalShareNameNotifier.new,
    );
