import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../messages/chat-list/chat_search.dart';
import '../../messages/chat-list/you-sheet/index.dart';
import '../../messages/chat-list/you-sheet/you_sheet_action.dart';
import '../../messages/chat_icon.dart';
import '../../privacy-mode/privacy_header_badge.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../quick-views/quick_view_summary.dart';

/// The greeting that tops Home: time of day small and muted, the person's
/// first name large under it, search and their own face on the right.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  static String greetingKey(DateTime now) => switch (now.hour) {
    >= 5 && < 12 => 'home_greet_morning',
    >= 12 && < 17 => 'home_greet_afternoon',
    _ => 'home_greet_evening',
  };

  /// The first word of a display name; the whole name if it has one word.
  static String firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Future<void> _openYou(BuildContext context, WidgetRef ref) async {
    final bar = ref.read(shellBottomBarHiddenProvider.notifier);
    bar.state = true;
    YouSheetAction? action;
    try {
      action = await showYouSheet(context);
    } finally {
      bar.state = false;
    }
    if (!context.mounted) return;
    if (action == YouSheetAction.scanQrLogin) {
      await QrLoginFlow.start(context, ref);
    } else if (action == YouSheetAction.localShare) {
      context.push('/local-share');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final user = ref.watch(profileProvider).valueOrNull;
    final name = firstName(user?.name ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homeText(context, ref, greetingKey(DateTime.now())),
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'AbabilX' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const PrivacyHeaderBadge(),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => openChatSearch(context, ref),
            icon: ChatIcon(
              HugeIcons.strokeRoundedSearch01,
              color: colors.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: () => QrLoginFlow.start(context, ref),
            icon: ChatIcon(
              HugeIcons.strokeRoundedQrCode,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _openYou(context, ref),
            child: _OwnFace(name: user?.name, url: user?.avatarUrl),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Own face: circular, with the online green (or privacy shield) mark — same
/// rule as the chat-list header pill.
class _OwnFace extends ConsumerWidget {
  const _OwnFace({this.name, this.url});

  final String? name;
  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final private = ref.watch(privacyModeProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: AppAvatar(size: 40, url: url, name: name),
        ),
        if (private)
          Positioned(
            right: -2,
            bottom: -2,
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
              width: 12,
              height: 12,
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
