import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../chat_icon.dart';

/// Chat-list header avatar — status lives in the title slot, not beside this.
class HeaderProfilePill extends StatelessWidget {
  const HeaderProfilePill({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.onProfileTap,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap,
      child: _PillAvatar(name: name, url: avatarUrl),
    );
  }
}

/// The corner mark is the green online dot, or — while this account's own
/// privacy mode is on — a shield: peers see "Privacy" instead of online then,
/// so a green dot here would claim something nobody else is shown.
class _PillAvatar extends ConsumerWidget {
  const _PillAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final private = ref.watch(privacyModeProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppAvatar(size: 30, url: url, name: name),
        if (private)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: ChatIcon(
                HugeIcons.strokeRoundedShield01,
                size: 9,
                color: colors.onPrimary,
              ),
            ),
          )
        else
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
