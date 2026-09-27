import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';
import '../../../shared/text/latin_tracking.dart';

Future<void> showUserProfileSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  String? userName,
  String? userAvatarUrl,
}) async {
  if (userId.isEmpty) return;

  final currentUserId = ref.read(chatProvider).currentUserId;
  final isSelf = userId == currentUserId;

  // Try to match with team members for extra details (role, email, preferred avatar/name).
  final teamMembers = ref.read(teamMembersProvider);
  final teamMember = teamMembers.where((tm) => tm.userId == userId).firstOrNull;

  final displayName =
      teamMember?.displayName ??
      (userName != null && userName.isNotEmpty ? userName : 'User');
  final avatarUrl = teamMember?.avatarUrl ?? userAvatarUrl;
  final role = teamMember?.role;
  final email = teamMember?.email;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return _UserProfileSheetContent(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role,
        email: email,
        isSelf: isSelf,
        ref: ref,
      );
    },
  );
}

class _UserProfileSheetContent extends StatefulWidget {
  const _UserProfileSheetContent({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role,
    this.email,
    required this.isSelf,
    required this.ref,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? role;
  final String? email;
  final bool isSelf;
  final WidgetRef ref;

  @override
  State<_UserProfileSheetContent> createState() =>
      _UserProfileSheetContentState();
}

class _UserProfileSheetContentState extends State<_UserProfileSheetContent> {
  bool _loading = false;

  Future<void> _onStartDm() async {
    setState(() => _loading = true);
    try {
      final dm = await widget.ref
          .read(chatProvider.notifier)
          .startDm(widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close bottom sheet
      context.push('/messages/${dm.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start direct message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // User Avatar
          AppAvatar(size: 76, url: widget.avatarUrl, name: widget.displayName),
          const SizedBox(height: 14),

          // Display Name
          Text(
            widget.displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          Consumer(
            builder: (context, ref, _) {
              final inCall = ref.watch(isUserInCallProvider(widget.userId));
              if (inCall) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: InCallLabel(),
                );
              }
              final status = ref.watch(userStatusForProvider(widget.userId));
              if (status == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: UserStatusBadge(status: status),
              );
            },
          ),

          if (widget.email != null && widget.email!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.email!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          if (widget.role != null && widget.role!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.role!.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: latinTracking(widget.role!, 0.5),
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          if (!widget.isSelf) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _loading ? null : _onStartDm,
                icon: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: Text(
                  _loading ? 'Opening Chat…' : 'Direct Message',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This is you',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
