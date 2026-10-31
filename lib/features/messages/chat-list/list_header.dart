import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../privacy-mode/privacy_header_badge.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat_icon.dart';
import 'brand_title.dart';
import 'chat_search.dart';
import 'header_profile_pill.dart';
import 'you-sheet/index.dart';
import 'you-sheet/you_sheet_action.dart';

/// Chat list header: identity pill, title, search, and the QR scanner.
///
/// The title slot is the brand ("AbabilX") until the account has a custom
/// status — then the status takes that same slot so the header stays one
/// line and the status does not sit beside the avatar. The brand shimmers while
/// the realtime socket is down ([ChatListBrandTitle]). Messages is the app's
/// home (`kAppHomePath`); the bottom bar already names this tab. Avatar and
/// a single tap on the title open the You sheet through [_openYouSheet].
/// Double-tap on the title flips privacy mode on the spot (same PUT as
/// Settings → Privacy mode) — no page, just the switch; the badge beside
/// the title is the confirmation. A long press opens the locked chats,
/// which appear nowhere else.
///
/// The scanner sits here because it is the one action that answers a prompt on
/// another screen — a desktop waiting to sign in, or a new device waiting for
/// this account's message key. Behind the avatar it was three taps deep
/// (avatar, sheet, Scan QR code) while the other device timed out. Local Share
/// gave up this slot for it: it is started from this phone at leisure, and the
/// route stays wired even while its menu rows are hidden. The filters this
/// row used to hold — unread and the personal/workspace scope — live in the
/// pill row under this header now (Slack's arrangement), where the current
/// selection is visible without opening anything.
class ChatListHeader extends ConsumerWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).valueOrNull;
    final name = user?.name.isNotEmpty == true ? user!.name : 'You';
    final status = ref.watch(userStatusForProvider(user?.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            HeaderProfilePill(
              name: name,
              avatarUrl: user?.avatarUrl,
              onProfileTap: () => _openYouSheet(context, ref),
            ),
            const SizedBox(width: 14),
            Expanded(
              // Single tap → You sheet; double tap → flip privacy mode.
              // `Align` keeps the hit target on the text only — a stray tap
              // between title and search does nothing. Transparent Material
              // hosts the ripple the same way `_SearchCapsule` does.
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openYouSheet(context, ref),
                    onDoubleTap: () => _togglePrivacyMode(context, ref),
                    // Door to locked chats; the list shows no folder row.
                    // Settings → Locked chats is the other one.
                    onLongPress: () => context.push('/messages/locked'),
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Flexible(
                            child: status != null
                                ? UserStatusBadge(status: status, plain: true)
                                : const ChatListBrandTitle(),
                          ),
                          // Own privacy mode, beside the title so it is
                          // never on unnoticed. Nothing while it is off.
                          const PrivacyHeaderBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _SearchCapsule(
              label: AppTranslations.translate(context, ref, 'chat_search'),
              onTap: () => openChatSearch(context, ref),
            ),
            IconButton(
              onPressed: () => QrLoginFlow.start(context, ref),
              icon: ChatIcon(
                HugeIcons.strokeRoundedQrCode,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Scan QR code',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openYouSheet(BuildContext context, WidgetRef ref) async {
    ref.read(shellBottomBarHiddenProvider.notifier).state = true;
    YouSheetAction? action;
    try {
      action = await showYouSheet(context);
    } finally {
      ref.read(shellBottomBarHiddenProvider.notifier).state = false;
    }
    if (!context.mounted) return;
    if (action == YouSheetAction.scanQrLogin) {
      await QrLoginFlow.start(context, ref);
    } else if (action == YouSheetAction.localShare) {
      context.push('/local-share');
    }
  }

  /// Same switch as Settings → Privacy mode — no navigation.
  Future<void> _togglePrivacyMode(BuildContext context, WidgetRef ref) async {
    final next = !ref.read(privacyModeProvider);
    final ok = await ref.read(privacyModeProvider.notifier).set(next);
    if (!ok && context.mounted) {
      showAppToast(
        context,
        AppTranslations.translate(context, ref, 'privacy_mode_save_failed'),
      );
    }
  }
}

/// Chat-list search: icon + label in a stadium hit target, no fill.
class _SearchCapsule extends StatelessWidget {
  const _SearchCapsule({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outlineVariant, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatIcon(
                HugeIcons.strokeRoundedSearch01,
                size: 22,
                color: foreground,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
