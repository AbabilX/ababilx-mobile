import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../providers/share_account.dart';

/// A device's picture: the account's avatar when the viewer may know whose it
/// is, otherwise a phone or laptop glyph. A green dot marks one in range.
class ShareDeviceAvatar extends ConsumerWidget {
  const ShareDeviceAvatar({
    super.key,
    required this.deviceType,
    required this.userId,
    this.size = 48,
    this.nearby = false,
  });

  final String deviceType;
  final String? userId;
  final double size;
  final bool nearby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final account = ref.watch(shareAccountProvider(userId));
    final glyph = deviceType == 'desktop'
        ? HugeIcons.strokeRoundedComputer
        : HugeIcons.strokeRoundedSmartPhone01;
    final face = account != null && account.avatarUrl.isNotEmpty
        ? ClipOval(
            child: AppAvatar(
              size: size,
              url: account.avatarUrl,
              name: account.name,
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ChatIcon(glyph, size: size * 0.46, color: colors.primary),
          );
    if (!nearby) return face;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        face,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
