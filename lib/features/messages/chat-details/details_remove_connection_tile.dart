import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import 'details_tile.dart';

/// "Remove connection" in a DM's red block, beside Block. Drawn only while
/// the two have an ACCEPTED connection (the connections list says so); the
/// caller hides it for Note to Self. Confirmed in a bottom sheet, then the
/// existing `DELETE /api/chat/connections/:userId`. History stays; the other
/// side cannot write again until this person accepts a new request.
class DetailsRemoveConnectionTile extends ConsumerStatefulWidget {
  const DetailsRemoveConnectionTile({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<DetailsRemoveConnectionTile> createState() => _State();
}

class _State extends ConsumerState<DetailsRemoveConnectionTile> {
  bool _busy = false;

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  /// What this phone calls them: a nickname set here wins.
  String get _name => ref
      .read(contactNicknamesProvider)
      .titleFor(widget.conversation, ref.read(chatProvider).currentUserId);

  @override
  void initState() {
    super.initState();
    // The list is not loaded by anything else on this screen.
    Future.microtask(
      () => ref.read(chatConnectionsProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerId = widget.conversation.peerUserId ?? '';
    final connected = ref
        .watch(chatConnectionsProvider)
        .connections
        .any((c) => c.user.userId == peerId);
    if (peerId.isEmpty || !connected) return const SizedBox.shrink();
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedUserRemove01),
      title: _tr('details_remove_connection'),
      destructive: true,
      onTap: _busy ? null : () => _run(peerId),
    );
  }

  Future<void> _run(String peerId) async {
    if (await _confirm() != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(chatConnectionsProvider.notifier).remove(peerId);
      if (!mounted) return;
      ref.read(chatProvider.notifier).fetchSidebarSilent().ignore();
      showAppToast(context, _tr('details_remove_connection_done'));
    } catch (error) {
      if (mounted) {
        showAppToast(context, friendlyErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm() {
    final theme = Theme.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tr(
                  'details_remove_connection_title',
                ).replaceAll('{name}', _name),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _tr(
                  'details_remove_connection_body',
                ).replaceAll('{name}', _name),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(sheet, true),
                child: Text(_tr('details_remove_connection_confirm')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: Text(_tr('cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
