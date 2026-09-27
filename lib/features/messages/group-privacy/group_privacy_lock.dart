import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/media_save_lock.dart';
import '../../privacy-mode/privacy_secure_scope.dart';
import '../../private-chat/private_chat_state.dart';
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
/// members' avatars — draws no Save and no Share. A DM with private chat on
/// (server 0160) holds it too: its media lives on the two phones only.
///
/// A private group also blocks screenshots and screen recording for every
/// member (2026-09-27) — Android `FLAG_SECURE` through [PrivacySecureScope]'s
/// counted hold. Viewers opened from these screens are routes above them, so
/// the window stays secure while one is up. Android only; iOS has no block.
class GroupPrivacyLock extends ConsumerWidget {
  const GroupPrivacyLock({
    super.key,
    required this.conversationId,
    required this.child,
  });

  final String conversationId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupPrivacy = ref.watch(
      conversationGroupPrivacyProvider(conversationId),
    );
    return PrivacySecureScope(
      active: groupPrivacy,
      child: MediaSaveLockScope(
        active:
            groupPrivacy || ref.watch(isPrivateChatProvider(conversationId)),
        child: child,
      ),
    );
  }
}
