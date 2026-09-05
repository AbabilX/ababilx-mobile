import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_details_provider.dart';
import '../providers/chat_provider.dart';

/// Picks which of the viewer's groups to pull this person into.
///
/// The list is the server's `can_add` hint, so it already excludes groups the
/// person is in and groups the viewer may not add to — but the add call is
/// still the authority, which is why a refusal is shown here rather than
/// assumed away.
Future<void> showAddToGroupSheet(
  BuildContext context, {
  required String peerUserId,
  required String peerName,
  required List<ChatGroupSummary> groups,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddToGroupSheet(
      peerUserId: peerUserId,
      peerName: peerName,
      groups: groups,
    ),
  );
}

class _AddToGroupSheet extends ConsumerStatefulWidget {
  const _AddToGroupSheet({
    required this.peerUserId,
    required this.peerName,
    required this.groups,
  });

  final String peerUserId;
  final String peerName;
  final List<ChatGroupSummary> groups;

  @override
  ConsumerState<_AddToGroupSheet> createState() => _AddToGroupSheetState();
}

class _AddToGroupSheetState extends ConsumerState<_AddToGroupSheet> {
  String? _busyGroupId;

  Future<void> _add(ChatGroupSummary group) async {
    setState(() => _busyGroupId = group.id);
    try {
      await ref
          .read(chatProvider.notifier)
          .addChannelMember(group.id, widget.peerUserId);
      ref.invalidate(chatGroupsInCommonProvider(widget.peerUserId));
      if (!mounted) return;
      // The toast is raised on the root overlay, so it outlives the pop on
      // the very next line — a bottom sheet's own SnackBar would not.
      showAppToast(context, '${widget.peerName} added to ${group.name}');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyGroupId = null);
      showAppToast(context, _failure(e, group), isError: true);
    }
  }

  String _failure(Object error, ChatGroupSummary group) {
    final code = error is DioException && error.response?.data is Map
        ? (error.response!.data as Map)['error']?.toString() ?? ''
        : '';
    return switch (code) {
      // Sealing a group key needs the new member's public key, so a person who
      // has never opened the app cannot be added to an encrypted group. It is
      // recoverable — they open AbabilX once — and naming that is the whole
      // point of catching it here.
      'member_needs_secure_messages' =>
        '${widget.peerName} needs to open AbabilX once before joining an '
            'encrypted group',
      'not_connected' ||
      'connection_required' => 'You can only add people you are connected to',
      _ => 'Could not add ${widget.peerName} to ${group.name}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Add ${widget.peerName} to',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.groups.length,
              itemBuilder: (_, i) {
                final group = widget.groups[i];
                final busy = _busyGroupId == group.id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: AppAvatar(
                    size: 44,
                    url: group.avatarUrl.isEmpty ? null : group.avatarUrl,
                    name: group.name,
                  ),
                  title: Text(group.name),
                  subtitle: Text('${group.memberCount} members'),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _busyGroupId == null ? () => _add(group) : null,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
