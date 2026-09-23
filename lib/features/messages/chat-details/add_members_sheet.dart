import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import 'add_members_empty.dart';
import '../../../shared/text/name_search.dart';

/// Who can still be added to this group, with a reason when that is nobody.
///
/// The old picker rendered a bare `Column` of candidates, so the common case —
/// every connection already in the group — drew an empty sheet that read as a
/// broken screen. Loading, empty and "no connections at all" are now three
/// distinct answers.
///
/// The candidate list is deliberately connections + workspace colleagues only:
/// the server requires an established relationship to be pulled into a
/// personal group, so searching strangers here would only produce 403s.
class AddMembersSheet extends ConsumerStatefulWidget {
  const AddMembersSheet({
    super.key,
    required this.conversation,
    required this.memberIds,
    required this.onAdded,
  });

  final ChatConversation conversation;
  final Set<String> memberIds;
  final VoidCallback onAdded;

  @override
  ConsumerState<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<AddMembersSheet> {
  String _query = '';
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    // Opened straight from a deep link the connections list can still be
    // empty, and an empty list here is indistinguishable from "nobody left".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connections = ref.read(chatConnectionsProvider);
      if (connections.connections.isEmpty && !connections.loading) {
        ref.read(chatConnectionsProvider.notifier).refresh();
      }
    });
  }

  List<ChatUserSummary> get _candidates {
    // Accepted connections only — the server's CanInviteToGroup. A workspace
    // colleague is somebody to message, not somebody to put in a room.
    final all = ref.watch(groupInvitablePeopleProvider);
    final query = _query.trim();
    return all
        .where((user) => !widget.memberIds.contains(user.userId))
        .where((user) => matchesNameQuery(query, [user.name]))
        .toList();
  }

  Future<void> _add(ChatUserSummary user) async {
    setState(() => _busyUserId = user.userId);
    try {
      await ref
          .read(chatProvider.notifier)
          .addChannelMember(widget.conversation.id, user.userId);
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyUserId = null);
      final private =
          e is DioException &&
          e.response?.data is Map &&
          (e.response!.data as Map)['error'] == 'peer_privacy_mode';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            private
                ? '${user.name} has privacy mode on and cannot be added to groups'
                : 'Could not add ${user.name}: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(chatConnectionsProvider).loading;
    final candidates = _candidates;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add members',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search people',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : candidates.isEmpty
                ? AddMembersEmpty(
                    conversation: widget.conversation,
                    filtered: _query.trim().isNotEmpty,
                  )
                : ListView.builder(
                    controller: scroll,
                    // Last row must clear the system navigation bar.
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
                    ),
                    itemCount: candidates.length,
                    itemBuilder: (_, i) {
                      final user = candidates[i];
                      return ListTile(
                        leading: ClipOval(
                          child: AppAvatar(
                            size: 42,
                            url: user.avatarUrl,
                            name: user.name,
                          ),
                        ),
                        title: Text(user.name),
                        trailing: _busyUserId == user.userId
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_outlined),
                        onTap: _busyUserId == null ? () => _add(user) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
