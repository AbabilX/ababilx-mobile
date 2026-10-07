import '../data/models/chat_message.dart';
import '../tiptap_plain_text.dart';

/// Wire values are the server's (0169) and may not be renamed.
enum TaskPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const TaskPriority(this.wire);
  final String wire;

  static TaskPriority parse(Object? raw) => values.firstWhere(
    (v) => v.wire == raw,
    orElse: () => TaskPriority.medium,
  );
}

enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  review('review'),
  blocked('blocked'),
  done('done'),
  cancelled('cancelled');

  const TaskStatus(this.wire);
  final String wire;

  /// Nothing left to do on it.
  bool get closed => this == done || this == cancelled;

  static TaskStatus parse(Object? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => TaskStatus.todo);
}

/// The task half of a task card: a DM message whose `meta.task` carries a
/// priority and a status both people may change. The title, description and
/// files are the message's own body and attachments.
class TaskCardData {
  const TaskCardData({required this.priority, required this.status});

  final TaskPriority priority;
  final TaskStatus status;

  /// Null when [message] is not a task card.
  static TaskCardData? of(ChatMessage message) {
    final task = message.meta?['task'];
    if (task is! Map || message.isDeleted) return null;
    return TaskCardData(
      priority: TaskPriority.parse(task['priority']),
      status: TaskStatus.parse(task['status']),
    );
  }
}

/// The meta a task card carries while it is still sending.
Map<String, dynamic> pendingTaskMeta(String priority) => {
  'task': {'priority': priority, 'status': TaskStatus.todo.wire},
};

/// [message]'s meta with the task moved. Every other key is kept.
Map<String, dynamic> taskMetaWith(
  ChatMessage message, {
  TaskPriority? priority,
  TaskStatus? status,
}) {
  final meta = Map<String, dynamic>.from(message.meta ?? const {});
  final task = Map<String, dynamic>.from(meta['task'] as Map? ?? const {});
  if (priority != null) task['priority'] = priority.wire;
  if (status != null) task['status'] = status.wire;
  meta['task'] = task;
  return meta;
}

/// One body holds both: the first line is the title, the rest the
/// description. A client that knows nothing of tasks shows it as that text.
String taskBodyText(String title, String description) {
  final head = title.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ');
  final rest = description.trim();
  return rest.isEmpty ? head : '$head\n$rest';
}

({String title, String description}) taskText(ChatMessage message) {
  final plain = tiptapToPlainText(message.body).trim();
  final cut = plain.indexOf('\n');
  if (cut < 0) return (title: plain, description: '');
  return (
    title: plain.substring(0, cut).trim(),
    description: plain.substring(cut + 1).trim(),
  );
}
