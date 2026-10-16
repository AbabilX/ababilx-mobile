import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../profile/providers/profile_provider.dart';

const _key = 'local_share_pinned_v1';

/// Pinned device threads allowed at once. Same four as the server's cap on
/// pinned conversations, so the top of the list never grows past what a
/// phone shows without scrolling.
const maxPinnedShareThreads = 4;

/// The device threads the user pinned in the chat list, by device id. Like
/// the thread's place in the list itself it lives on this phone, per account;
/// a Local Share thread has no server row to pin.
class ShareChatPinsNotifier extends AsyncNotifier<Set<String>> {
  String? _userId;

  @override
  Future<Set<String>> build() async {
    _userId = ref.watch(profileProvider.select((p) => p.valueOrNull?.id));
    final userId = _userId;
    if (userId == null || userId.isEmpty) return const {};
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList('$_key:$userId')};
  }

  /// False when pinning would pass [maxPinnedShareThreads]; unpinning, and
  /// pinning something already pinned, always succeed.
  Future<bool> setPinned(String deviceId, bool pinned) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return false;
    final next = {...?state.valueOrNull};
    if (pinned &&
        !next.contains(deviceId) &&
        next.length >= maxPinnedShareThreads) {
      return false;
    }
    if (!(pinned ? next.add(deviceId) : next.remove(deviceId))) return true;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_key:$userId', next.toList());
    return true;
  }
}

final shareChatPinsProvider =
    AsyncNotifierProvider<ShareChatPinsNotifier, Set<String>>(
      ShareChatPinsNotifier.new,
    );
