import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/tiptap_plain_text.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../messages/tiptap_viewer.dart';
import '../../team/data/models/team_models.dart';
import '../data/board_repository.dart';
import '../data/models/board_models.dart';
import '../providers/board_detail_provider.dart';
import '../shared/kanban_utils.dart';
import 'comment_message_tile.dart';
import 'comment_thread_page.dart';
import 'comment_threads.dart';
import 'kanban_comment_composer.dart';
import 'thread_reply_summary.dart';
import '../../../shared/widgets/avatar_cache.dart';

class BoardTaskDetailPage extends ConsumerStatefulWidget {
  const BoardTaskDetailPage({
    super.key,
    required this.boardId,
    required this.taskId,
  });

  final String boardId;
  final String taskId;

  @override
  ConsumerState<BoardTaskDetailPage> createState() =>
      _BoardTaskDetailPageState();
}

class _BoardTaskDetailPageState extends ConsumerState<BoardTaskDetailPage> {
  void _openThread(KanbanTaskComment comment) {
    openCommentThread(
      context,
      boardId: widget.boardId,
      taskId: widget.taskId,
      commentId: comment.id,
    );
  }

  Future<void> _pickStatus(
    KanbanTaskDetail task,
    List<KanbanColumn> cols,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final col in cols)
              ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: columnAccent(col),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(col.label),
                trailing: task.status == col.key
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, col.key),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == task.status) return;
    await ref
        .read(boardDetailProvider(widget.boardId).notifier)
        .moveTask(task, picked);
    ref.invalidate(kanbanTaskProvider(task.id));
  }

  Future<void> _pickPriority(KanbanTaskDetail task) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in kanbanPriorities)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: p.color, size: 20),
                title: Text(p.label),
                trailing: task.priority == p.value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, p.value),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == task.priority) return;
    await ref.read(boardDetailProvider(widget.boardId).notifier).patchTask(
      task.id,
      {'priority': picked},
    );
    ref.invalidate(kanbanTaskProvider(task.id));
  }

  Future<void> _pickAssignee(
    KanbanTaskDetail task,
    List<TeamMember> members,
  ) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Unassigned'),
              trailing: task.assigneeId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final m in members)
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundImage: (m.avatarUrl ?? '').isNotEmpty
                      ? AvatarCache.provider(m.avatarUrl!)
                      : null,
                  child: (m.avatarUrl ?? '').isEmpty
                      ? Text(m.displayName.characters.first.toUpperCase())
                      : null,
                ),
                title: Text(m.displayName),
                trailing: task.assigneeId == m.userId
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, m.userId),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final body = picked.isEmpty
        ? {'clear_assignee': true}
        : {'assignee_id': picked};
    await ref
        .read(boardDetailProvider(widget.boardId).notifier)
        .patchTask(task.id, body);
    ref.invalidate(kanbanTaskProvider(task.id));
  }

  Future<void> _editTitle(KanbanTaskDetail task) async {
    final ctrl = TextEditingController(text: task.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || next.isEmpty || next == task.title) return;
    await ref.read(boardDetailProvider(widget.boardId).notifier).patchTask(
      task.id,
      {'title': next},
    );
    ref.invalidate(kanbanTaskProvider(task.id));
  }

  Future<void> _editDescription(KanbanTaskDetail task) async {
    final ctrl = TextEditingController(
      text: tiptapToPlainText(task.description),
    );
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit description'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Description (plain text on mobile)',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || next == tiptapToPlainText(task.description)) return;
    await ref.read(boardDetailProvider(widget.boardId).notifier).patchTask(
      task.id,
      {'description': textToTiptapJson(next)},
    );
    ref.invalidate(kanbanTaskProvider(task.id));
  }

  Future<void> _delete(KanbanTaskDetail task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await ref
        .read(boardDetailProvider(widget.boardId).notifier)
        .deleteTask(task.id);
    if (deleted && mounted) context.pop();
  }

  List<PopupMenuEntry<String>> _menuItems() {
    final colors = Theme.of(context).colorScheme;
    return [
      const PopupMenuItem(value: 'title', child: Text('Edit title')),
      const PopupMenuItem(
        value: 'description',
        child: Text('Edit description'),
      ),
      const PopupMenuItem(value: 'status', child: Text('Change status')),
      const PopupMenuItem(value: 'priority', child: Text('Change priority')),
      const PopupMenuItem(value: 'assignee', child: Text('Change assignee')),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Text('Delete task', style: TextStyle(color: colors.error)),
      ),
    ];
  }

  void _onMenuSelected(
    String value,
    KanbanTaskDetail task,
    List<KanbanColumn> columns,
    List<TeamMember> members,
  ) {
    switch (value) {
      case 'title':
        _editTitle(task);
      case 'description':
        _editDescription(task);
      case 'status':
        _pickStatus(task, columns);
      case 'priority':
        _pickPriority(task);
      case 'assignee':
        _pickAssignee(task, members);
      case 'delete':
        _delete(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(kanbanTaskProvider(widget.taskId));
    final boardState = ref.watch(boardDetailProvider(widget.boardId));
    final members = ref.watch(teamMembersProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return taskAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not load task\n$e')),
      ),
      data: (task) {
        final threads = buildCommentThreads(task.comments);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBarBackButton(),
            title: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) =>
                    _onMenuSelected(v, task, boardState.columns, members),
                itemBuilder: (_) => _menuItems(),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    if ((task.taskKey ?? '').isNotEmpty) ...[
                      Text(
                        task.taskKey!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Description',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: TiptapViewer(
                            content: task.description,
                            emptyPlaceholder: 'No description',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Comments (${threads.roots.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Double-tap a comment to open its thread',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (threads.roots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No comments yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final root in threads.roots) ...[
                        CommentMessageTile(
                          comment: root,
                          onDoubleTap: () => _openThread(root),
                          onTap: () {
                            if (threads.replyCount(root.id) > 0) {
                              _openThread(root);
                            }
                          },
                        ),
                        if (threads.replyCount(root.id) > 0)
                          ThreadReplySummary(
                            root: root,
                            replies: threads.repliesFor(root.id),
                            onTap: () => _openThread(root),
                          ),
                      ],
                  ],
                ),
              ),
              KanbanCommentComposer(
                taskId: task.id,
                hintName: 'comment',
                sendLabelKey: 'Post',
                onSubmit: ({required bodyJson, required attachments}) async {
                  await ref
                      .read(boardRepositoryProvider)
                      .createComment(
                        task.id,
                        bodyJson,
                        attachments: attachments,
                      );
                  ref.invalidate(kanbanTaskProvider(task.id));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
