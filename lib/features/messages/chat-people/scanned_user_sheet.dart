import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_connection.dart';
import '../providers/chat_provider.dart';
import 'user_qr_payload.dart';

/// What a scanned personal QR code opens: the person it points at, and one
/// button to start talking to them.
///
/// The lookup happens here rather than in the scanner so the camera closes the
/// moment a code is read — a spinner over a live preview reads as a scan that
/// did not work. Scanning your own code is answered before the request goes
/// out; the server excludes the caller from the lookup, so it would otherwise
/// come back as "no such account", which is a confusing thing to be told about
/// yourself.
class ScannedUserSheet {
  ScannedUserSheet._();

  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    String username,
  ) async {
    final me = ref.read(profileProvider).valueOrNull;
    final byContact = isEmailRef(username) || isPhoneRef(username);
    if (me != null &&
        ((me.username.isNotEmpty && me.username == username) ||
            (me.email.isNotEmpty && me.email.toLowerCase() == username))) {
      showAppToast(context, 'That is your own QR code.');
      return;
    }

    ChatUserSummary? user;
    try {
      final repo = ref.read(chatRepositoryProvider);
      // An email or a number goes through people search, which matches both
      // exactly and only finds someone whose switch for it is on — so a link
      // stops working the moment its owner turns that switch off.
      user = byContact
          ? (await repo.searchUsers(username)).users.firstOrNull
          : await repo.lookupUserByUsername(username);
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, 'Could not look that code up.', isError: true);
      }
      return;
    }
    if (!context.mounted) return;
    if (user == null) {
      // A blocked pair resolves to nothing as well, deliberately: telling the
      // scanner "you are blocked" is telling them something the block exists
      // to withhold.
      showAppToast(
        context,
        byContact
            ? 'No account can be found by $username.'
            : 'No account uses @$username.',
        isError: true,
      );
      return;
    }

    final found = user;
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => _ScannedUserBody(user: found),
      );
    } finally {
      hidden.state = false;
    }
  }
}

class _ScannedUserBody extends ConsumerStatefulWidget {
  const _ScannedUserBody({required this.user});

  final ChatUserSummary user;

  @override
  ConsumerState<_ScannedUserBody> createState() => _ScannedUserBodyState();
}

class _ScannedUserBodyState extends ConsumerState<_ScannedUserBody> {
  bool _opening = false;

  Future<void> _message() async {
    setState(() => _opening = true);
    try {
      final dm = await ref
          .read(chatProvider.notifier)
          .startDm(widget.user.userId);
      if (!mounted) return;
      // The toast is not needed on success — the chat itself is the answer.
      Navigator.of(context).pop();
      context.push('/messages/${dm.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _opening = false);
      showAppToast(context, 'Could not open the chat.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = widget.user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(size: 88, url: user.avatarUrl, name: user.name),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (user.username.isNotEmpty)
              Text(
                '@${user.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _opening ? null : _message,
                icon: _opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
