import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/chat_provider.dart';
import 'group_link_api.dart';

/// What a group's public link opens: the group it points at, and one button
/// to join it. Nothing is joined by opening the link — the sheet is the
/// confirmation, the same way a scanned personal code only shows a person.
class GroupLinkJoinSheet {
  GroupLinkJoinSheet._();

  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    String slug,
  ) async {
    GroupLinkPreview? group;
    try {
      group = await fetchGroupLink(ref.read(apiClientProvider), slug);
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, 'Could not open that link.', isError: true);
      }
      return;
    }
    if (!context.mounted) return;
    if (group == null) {
      showAppToast(context, 'This group link no longer works.', isError: true);
      return;
    }
    if (group.isMember) {
      context.push('/messages/${group.conversationId}');
      return;
    }

    final found = group;
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _JoinBody(slug: slug, group: found),
      );
    } finally {
      hidden.state = false;
    }
  }
}

class _JoinBody extends ConsumerStatefulWidget {
  const _JoinBody({required this.slug, required this.group});

  final String slug;
  final GroupLinkPreview group;

  @override
  ConsumerState<_JoinBody> createState() => _JoinBodyState();
}

class _JoinBodyState extends ConsumerState<_JoinBody> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final id = await joinGroupLink(ref.read(apiClientProvider), widget.slug);
      // The chat screen reads its row from the sidebar.
      await ref.read(chatProvider.notifier).fetchSidebarSilent();
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/messages/$id');
    } on GroupLinkRefused catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      showAppToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final group = widget.group;
    final count = group.memberCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(size: 88, url: group.avatarUrl, name: group.name),
            const SizedBox(height: 16),
            Text(
              group.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text('$count ${count == 1 ? 'member' : 'members'}', style: muted),
            if (group.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                group.description,
                style: muted,
                maxLines: 4,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _joining ? null : _join,
                child: Text(_joining ? 'Joining…' : 'Join group'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
