import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../privacy-mode/privacy_header_badge.dart';
import '../../../privacy-mode/privacy_mode_provider.dart';
import '../../../profile/providers/user_status_provider.dart';
import '../../../profile/widgets/user_status_badge.dart';
import '../../chat_icon.dart';
import 'set_status_sheet.dart';

/// Centered identity block: avatar → name → tappable status (pen = editable).
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
          // Own privacy mode, under the name. The badge pads its own left
          // edge for the header row; offset it here so it sits centred.
          if (ref.watch(privacyModeProvider))
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: PrivacyHeaderBadge(),
            ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showSetStatusSheet(context, ref, currentUserId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
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
                  const SizedBox(width: 6),
                  ChatIcon(
                    HugeIcons.strokeRoundedEdit02,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
