import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/media_save_lock.dart';
import '../providers/chat_provider.dart';

/// Whether [conversationId] is a private group (server 0154).
final conversationGroupPrivacyProvider = Provider.family<bool, String>(
  (ref, conversationId) => ref.watch(
    chatProvider.select(
      (s) => s.conversationById(conversationId)?.groupPrivacy ?? false,
    ),
  ),
);

/// Holds [MediaSaveLock] while a private group's screen is up, so every
/// viewer opened from it — photos, videos, files, the group's pictures and
/// members' avatars — draws no Save and no Share.
class GroupPrivacyLock extends ConsumerWidget {
  const GroupPrivacyLock({
    super.key,
    required this.conversationId,
    required this.child,
  });

  final String conversationId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaSaveLockScope(
    active: ref.watch(conversationGroupPrivacyProvider(conversationId)),
    child: child,
  );
}
