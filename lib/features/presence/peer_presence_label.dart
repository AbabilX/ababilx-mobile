import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_translations.dart';
import 'online_dot.dart';
import 'online_presence_provider.dart';

/// "Online" or "Offline" under a DM peer's name.
///
/// [showOffline] is false where the server would never tell us either way —
/// presence reaches only accepted connections and teammates, so an open
/// message request saying "Offline" would be a guess dressed as a fact.
class PeerPresenceLabel extends ConsumerWidget {
  const PeerPresenceLabel({
    super.key,
    required this.userId,
    this.showOffline = true,
  });

  final String? userId;
  final bool showOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isUserOnlineProvider(userId));
    if (!online && !showOffline) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final label = Text(
      AppTranslations.translate(
        context,
        ref,
        online ? 'chat_status_online' : 'chat_status_offline',
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
    );
    if (!online) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnlineDot(size: 8),
        const SizedBox(width: 4),
        Flexible(child: label),
      ],
    );
  }
}
