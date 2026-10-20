import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/data/models/chat_models.dart';
import '../../messages/send-later/scheduled_list_sheet.dart';
import '../data/home_chats.dart';
import '../data/home_drafts.dart';
import '../quick-views/quick_view_summary.dart';
import 'home_draft_tile.dart';
import 'home_page_scaffold.dart';

/// Drafts & scheduled (Slack's "Drafts & sent"): messages waiting on the
/// server to go out at their time, then text left unsent in a composer.
/// A scheduled row opens its own actions (send now, change time, delete); a
/// draft opens its chat with the text still in the composer.
class HomeDraftsPage extends ConsumerWidget {
  const HomeDraftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(homeConversationsProvider);
    final scheduled = [
      for (final s in ref.watch(homeScheduledProvider).valueOrNull ?? const [])
        if (homeConversationById(conversations, s.conversationId) != null) s,
    ];
    final drafts = ref.watch(homeDraftsProvider).valueOrNull ?? const [];
    final loading =
        ref.watch(homeScheduledProvider).isLoading ||
        ref.watch(homeDraftsProvider).isLoading;
    final empty = scheduled.isEmpty && drafts.isEmpty;
    return HomePageScaffold(
      title: homeText(context, ref, 'home_drafts'),
      body: empty && loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : empty
          ? HomePageEmpty(homeText(context, ref, 'home_no_drafts'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(homeDraftsProvider);
                ref.invalidate(homeScheduledProvider);
                await ref.read(homeScheduledProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (scheduled.isNotEmpty) ...[
                    _Heading(homeText(context, ref, 'home_scheduled_section')),
                    for (final s in scheduled)
                      _InChat(
                        conversation: homeConversationById(
                          conversations,
                          s.conversationId,
                        )!,
                        child: ScheduledRow(key: ValueKey(s.id), row: s),
                      ),
                  ],
                  if (drafts.isNotEmpty) ...[
                    _Heading(homeText(context, ref, 'home_drafts_section')),
                    for (final d in drafts)
                      HomeDraftTile(
                        draft: d,
                        onTap: () async {
                          final thread = d.draft.parentId;
                          await context.push(
                            '/messages/${d.conversation.id}'
                            '${thread == null ? '' : '?thread=$thread'}',
                          );
                          ref.invalidate(homeDraftsProvider);
                        },
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A scheduled row under the name of the chat it goes to.
class _InChat extends StatelessWidget {
  const _InChat({required this.conversation, required this.child});

  final ChatConversation conversation;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomeChatLabel(conversation: conversation),
      child,
    ],
  );
}
