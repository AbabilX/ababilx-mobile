import '../data/models/board_models.dart';

class CommentThreads {
  const CommentThreads({
    required this.roots,
    required this.repliesByParent,
    required this.byId,
  });

  final List<KanbanTaskComment> roots;
  final Map<String, List<KanbanTaskComment>> repliesByParent;
  final Map<String, KanbanTaskComment> byId;

  List<KanbanTaskComment> repliesFor(String rootId) =>
      repliesByParent[rootId] ?? const [];

  int replyCount(String rootId) => repliesFor(rootId).length;

  KanbanTaskComment threadRoot(String messageId) {
    var current = byId[messageId];
    if (current == null) {
      throw StateError('Comment not found: $messageId');
    }
    while (current!.parentId != null && current.parentId!.isNotEmpty) {
      final parent = byId[current.parentId!];
      if (parent == null) break;
      current = parent;
    }
    return current;
  }
}

CommentThreads buildCommentThreads(List<KanbanTaskComment> messages) {
  final byId = {for (final m in messages) m.id: m};
  final roots = <KanbanTaskComment>[];
  final repliesByParent = <String, List<KanbanTaskComment>>{};

  for (final m in messages) {
    if (!m.isRoot) {
      final parentId = m.parentId!;
      repliesByParent.putIfAbsent(parentId, () => []).add(m);
    } else {
      roots.add(m);
    }
  }

  int desc(String a, String b) =>
      DateTime.parse(b).compareTo(DateTime.parse(a));
  int asc(String a, String b) => DateTime.parse(a).compareTo(DateTime.parse(b));

  roots.sort((a, b) => desc(a.createdAt, b.createdAt));
  for (final replies in repliesByParent.values) {
    replies.sort((a, b) => asc(a.createdAt, b.createdAt));
  }

  return CommentThreads(
    roots: roots,
    repliesByParent: repliesByParent,
    byId: byId,
  );
}
