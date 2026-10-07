import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import 'call_favorite.dart';

/// One favourite: picture and first name, the strip's whole vocabulary.
///
/// Name and picture come from the live conversation when the phone has it —
/// so a nickname or a new photo shows — else from the stored copy, which is
/// what makes the strip draw offline.
class CallFavoriteTile extends ConsumerWidget {
  const CallFavoriteTile({
    super.key,
    required this.favorite,
    required this.onTap,
    this.onLongPress,
  });

  final CallFavorite favorite;

  /// Null while a call is already up: the tile dims, like the redial buttons.
  final VoidCallback? onTap;

  /// Left null where the tile is dragged: a long-press handler here would win
  /// the gesture race against the drag.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final live = chat.conversationById(favorite.conversationId);
    final name = live == null
        ? favorite.name
        : ref
              .watch(contactNicknamesProvider)
              .titleFor(live, chat.currentUserId);
    final avatar = live?.peerUserAvatar ?? favorite.avatarUrl;
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppAvatar.radius),
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: SizedBox(
            width: 64,
            child: Column(
              children: [
                AppAvatar(size: 56, url: avatar, name: name),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip's last tile: opens the picker.
class CallFavoriteAddTile extends StatelessWidget {
  const CallFavoriteAddTile({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppAvatar.radius),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              // Same rounded square as every avatar beside it.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppAvatar.radius),
                color: scheme.surfaceContainerHighest,
              ),
              child: Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
