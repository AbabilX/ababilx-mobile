import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text/display_name.dart';
import '../providers/chat_provider.dart';
import 'member_key_changes.dart';
import 'safety_number_screen.dart';
import 'safety_number_strip.dart';

/// A group's half of the key-change watch: says so, in the group, when a
/// member's identity key is not the one this phone remembers. Draws nothing
/// otherwise.
class GroupKeyChangeBanner extends ConsumerWidget {
  const GroupKeyChangeBanner({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changed =
        ref.watch(memberKeyChangesProvider(conversationId)).valueOrNull ??
        const <String>[];
    if (changed.isEmpty) return const SizedBox.shrink();
    // The roster carries ids only. A name comes from what this member wrote
    // in the open chat; someone who never wrote here is "A member".
    final messages = ref.watch(
      chatProvider.select((s) => s.feedFor(conversationId).messages),
    );
    String nameOf(String userId) {
      for (final m in messages) {
        if (m.userId == userId && (m.userName ?? '').trim().isNotEmpty) {
          return safeDisplayName(m.userName, fallback: 'A member');
        }
      }
      return 'A member';
    }

    void verify(String userId) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SafetyNumberScreen(peerUserId: userId, peerName: nameOf(userId)),
      ),
    );

    if (changed.length == 1) {
      return SafetyNumberStrip(
        text:
            'Your safety number with ${nameOf(changed.first)} changed. '
            'Tap to verify.',
        onTap: () => verify(changed.first),
      );
    }
    return SafetyNumberStrip(
      text:
          'Safety numbers changed for ${changed.length} members. '
          'Tap to review.',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final userId in changed)
                ListTile(
                  title: Text(nameOf(userId)),
                  subtitle: const Text('Safety number changed'),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    verify(userId);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
