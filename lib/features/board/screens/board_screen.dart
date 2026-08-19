import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-empty-state/index.dart';
import '../../../core/network/friendly_error.dart';
import '../../messages/chat_icon.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../data/models/board_models.dart';
import '../providers/board_provider.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamGateProvider);

    return teamAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (error, _) => Scaffold(body: LoadErrorState(error)),
      data: (detail) {
        if (detail == null || !detail.hasTeam) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppTranslations.translate(context, ref, 'board')),
            ),
            body: const ChatEmptyState(
              title: 'No team yet',
              subtitle: 'Join or create a team to use boards.',
              icon: Icons.groups_outlined,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(AppTranslations.translate(context, ref, 'board')),
          ),
          body: const _BoardListBody(),
        );
      },
    );
  }
}

class _BoardListBody extends ConsumerWidget {
  const _BoardListBody();

  void _openBoard(BuildContext context, KanbanBoard board) {
    context.push('/board/${board.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(kanbanBoardsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return boardsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (e, _) => LoadErrorState(e),
      data: (boards) {
        if (boards.isEmpty) {
          return const ChatEmptyState(
            title: 'No boards yet',
            subtitle: 'Create a board on the web to get started.',
            icon: Icons.view_kanban_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(kanbanBoardsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: boards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final board = boards[i];
              final columnCount = board.columns.length;
              return Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => _openBoard(context, board),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.65),
                        width: 0.9,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: ChatIcon(
                                HugeIcons.strokeRoundedTask01,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  board.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  columnCount == 0
                                      ? 'Kanban board'
                                      : '$columnCount column${columnCount == 1 ? '' : 's'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
