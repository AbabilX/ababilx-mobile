import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../profile/providers/profile_provider.dart';
import '../data/share_thread_queries.dart';
import 'local_share_providers.dart';

const _key = 'local_share_in_chats_v1';

/// The device threads the user moved into the ordinary chat list, by device
/// id. Kept on this phone, per account — like the thread itself, the choice
/// never reaches the server.
class ShareInChatsNotifier extends AsyncNotifier<Set<String>> {
  String? _userId;

  @override
  Future<Set<String>> build() async {
    _userId = ref.watch(profileProvider.select((p) => p.valueOrNull?.id));
    final userId = _userId;
    if (userId == null || userId.isEmpty) return const {};
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList('$_key:$userId')};
  }

  Future<void> setShown(String deviceId, bool shown) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    final next = {...?state.valueOrNull};
    if (!(shown ? next.add(deviceId) : next.remove(deviceId))) return;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_key:$userId', next.toList());
  }
}

final shareInChatsProvider =
    AsyncNotifierProvider<ShareInChatsNotifier, Set<String>>(
      ShareInChatsNotifier.new,
    );

/// The threads the chat list draws beside its conversations. A blocked device
/// is left out: a chat row nothing can be sent to or received from is noise.
final shareChatThreadsProvider = Provider<List<ShareThread>>((ref) {
  final shown = ref.watch(shareInChatsProvider).valueOrNull ?? const {};
  if (shown.isEmpty) return const [];
  final threads = ref.watch(localShareThreadsProvider).valueOrNull ?? const [];
  return [
    for (final t in threads)
      if (shown.contains(t.device.deviceId) && !t.device.blocked) t,
  ];
});
