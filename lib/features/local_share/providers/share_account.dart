import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/providers/chat_connections_provider.dart';
import '../../profile/providers/profile_provider.dart';

/// Who a nearby device says it belongs to, as far as this account may know.
class ShareAccount {
  const ShareAccount({
    required this.name,
    this.avatarUrl = '',
    this.mine = false,
  });

  final String name;
  final String avatarUrl;

  /// The device is signed in to this same account.
  final bool mine;
}

/// The account behind an announced user id — only for the viewer's own
/// account and their accepted connections. For anyone else the id means
/// nothing here and the device is shown by its own name alone.
///
/// The id is a claim the device makes about itself and is never proved, so
/// this decides a label and nothing else.
final shareAccountProvider = Provider.family<ShareAccount?, String?>((ref, id) {
  if (id == null || id.isEmpty) return null;
  final me = ref.watch(profileProvider).valueOrNull;
  if (me != null && me.id == id) {
    return ShareAccount(name: me.name, avatarUrl: me.avatarUrl, mine: true);
  }
  for (final c in ref.watch(chatConnectionsProvider).connections) {
    if (c.user.userId == id) {
      return ShareAccount(name: c.user.name, avatarUrl: c.user.avatarUrl);
    }
  }
  return null;
});
