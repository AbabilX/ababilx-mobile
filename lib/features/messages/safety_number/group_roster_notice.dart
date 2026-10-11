import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../message_e2ee/group_roster_pins.dart';
import '../providers/chat_provider.dart';
import 'group_roster_sheet.dart';
import 'member_key_changes.dart';

/// The members of a group who appeared in the list its keys are sealed to
/// since the user last looked, by user id (GroupRosterPins).
final groupRosterNewsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, conversationId) async {
      final myId = ref.watch(chatProvider.select((s) => s.currentUserId));
      if (myId.isEmpty || conversationId.isEmpty) return const [];
      void moved() => ref.invalidateSelf();
      GroupRosterPins.changes.addListener(moved);
      ref.onDispose(() => GroupRosterPins.changes.removeListener(moved));
      return const GroupRosterPins().unseen(myId, conversationId);
    });

/// The capsule above a group's composer while someone new can read it:
/// "2 new people can read this chat". A tap lists them, and that is the look
/// that clears it.
///
/// It is this phone's own word. The server's "Alice added Bob" line is a
/// message like any other and can be left out by the same database write
/// that adds a member; the list this is drawn from is the one the phone
/// seals its keys to.
class GroupRosterNotice extends ConsumerWidget {
  const GroupRosterNotice({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The roster is read when the group opens; that read fills the record.
    ref.watch(memberKeyChangesProvider(conversationId));
    final fresh =
        ref.watch(groupRosterNewsProvider(conversationId)).valueOrNull ??
        const <String>[];
    if (fresh.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final count = fresh.length;
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          color: colors.surfaceContainerHighest,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showGroupRosterSheet(
              context,
              conversationId: conversationId,
              memberIds: fresh,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatIcon(
                    HugeIcons.strokeRoundedUserAdd01,
                    size: 16,
                    color: colors.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    count == 1
                        ? '1 new person can read this chat'
                        : '$count new people can read this chat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
