import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../providers/blocked_connections_provider.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import 'details_tile.dart';

/// Block or Unblock on a DM's details screen, whichever is true right now.
///
/// `lock_reason: blocked` cannot say who placed the block — it is the same for
/// both people, on purpose. The blocked-people list holds only blocks the
/// viewer owns, so it is the one source that can offer Unblock without telling
/// anybody they were blocked. A block placed by the peer shows plain Block.
///
/// Neither action leaves the screen: the history stays, and the row flipping
/// to its opposite is the confirmation.
class DetailsBlockTile extends ConsumerStatefulWidget {
  const DetailsBlockTile({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<DetailsBlockTile> createState() => _DetailsBlockTileState();
}

class _DetailsBlockTileState extends ConsumerState<DetailsBlockTile> {
  bool _busy = false;

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  String get _name => widget.conversation.peerUserName ?? 'this person';

  @override
  Widget build(BuildContext context) {
    final peerId = widget.conversation.peerUserId!;
    final blocked = ref.watch(blockedConnectionsProvider).valueOrNull;
    // Until the list answers, a blocked chat cannot tell whose block it is;
    // drawing nothing beats offering Block on a person already blocked.
    if (blocked == null && widget.conversation.lockReason == 'blocked') {
      return const SizedBox.shrink();
    }
    final blockedByMe = blocked?.any((c) => c.user.userId == peerId) ?? false;
    return DetailsTile(
      icon: Icon(
        blockedByMe ? Icons.check_circle_outline_rounded : Icons.block_rounded,
      ),
      title: _tr(blockedByMe ? 'chat_unblock' : 'chat_block'),
      destructive: !blockedByMe,
      onTap: _busy ? null : () => _run(peerId, unblock: blockedByMe),
    );
  }

  Future<void> _run(String peerId, {required bool unblock}) async {
    final ok = await _confirm(unblock);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final connections = ref.read(chatConnectionsProvider.notifier);
    try {
      // DELETE lifts only our own block; it does not restore acceptance.
      unblock
          ? await connections.remove(peerId)
          : await connections.block(peerId);
      if (!mounted) return;
      ref.invalidate(blockedConnectionsProvider);
      ref.read(chatProvider.notifier).fetchSidebarSilent().ignore();
      showAppToast(context, _tr(unblock ? 'chat_unblocked' : 'chat_blocked'));
    } catch (error) {
      if (mounted) {
        showAppToast(context, friendlyErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(bool unblock) {
    final colors = Theme.of(context).colorScheme;
    final title = _tr(
      unblock ? 'chat_unblock_person_title' : 'chat_block_connection_title',
    ).replaceAll('{name}', _name);
    final body = _tr(
      unblock ? 'chat_unblock_person_confirm' : 'chat_block_connection_confirm',
    );
    return showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_tr('cancel')),
          ),
          FilledButton(
            style: unblock
                ? null
                : FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(_tr(unblock ? 'chat_unblock' : 'chat_block')),
          ),
        ],
      ),
    );
  }
}
