import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../profile/providers/user_status_provider.dart';
import '../../../profile/widgets/user_status_badge.dart';
import 'set_status_sheet.dart';

/// Centered identity block: avatar → name → tappable status.
class YouIdentity extends ConsumerWidget {
  const YouIdentity({
    super.key,
    required this.name,
    required this.currentUserId,
    this.avatarUrl,
  });

  final String name;
  final String currentUserId;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final status = ref.watch(userStatusForProvider(currentUserId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          AppAvatar(size: 88, url: avatarUrl, name: name),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showSetStatusSheet(context, ref, currentUserId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: status != null
                  ? UserStatusBadge(status: status)
                  : Text(
                      "What's your status?",
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
