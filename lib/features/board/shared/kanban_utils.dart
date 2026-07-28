import 'package:flutter/material.dart';

import '../data/models/board_models.dart';

const kanbanColumnWidth = 280.0;

const kanbanColumnAccents = <String, Color>{
  'task': Color(0xFF6366F1),
  'in_progress': Color(0xFFF59E0B),
  'in_review': Color(0xFF8B5CF6),
  'complete': Color(0xFF22C55E),
};

const defaultKanbanColumns = <KanbanColumn>[
  KanbanColumn(
    id: 'task',
    key: 'task',
    label: 'Task',
    position: 0,
    color: '#6366f1',
    role: 'todo',
  ),
  KanbanColumn(
    id: 'in_progress',
    key: 'in_progress',
    label: 'In Work',
    position: 1,
    color: '#f59e0b',
    role: 'active',
  ),
  KanbanColumn(
    id: 'in_review',
    key: 'in_review',
    label: 'In Review',
    position: 2,
    color: '#8b5cf6',
    role: 'review',
  ),
  KanbanColumn(
    id: 'complete',
    key: 'complete',
    label: 'Complete',
    position: 3,
    color: '#22c55e',
    role: 'done',
  ),
];

class KanbanPriorityMeta {
  const KanbanPriorityMeta(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;
}

const kanbanPriorities = <KanbanPriorityMeta>[
  KanbanPriorityMeta('none', 'None', Color(0xFF64748B)),
  KanbanPriorityMeta('low', 'Low', Color(0xFF3B82F6)),
  KanbanPriorityMeta('medium', 'Medium', Color(0xFFEAB308)),
  KanbanPriorityMeta('high', 'High', Color(0xFFF97316)),
  KanbanPriorityMeta('urgent', 'Urgent', Color(0xFFEF4444)),
];

List<KanbanColumn> resolveBoardColumns(List<KanbanColumn> columns) {
  if (columns.isEmpty) return defaultKanbanColumns;
  final sorted = [...columns]..sort((a, b) => a.position.compareTo(b.position));
  return sorted;
}

KanbanColumn? todoColumn(List<KanbanColumn> columns) {
  final resolved = resolveBoardColumns(columns);
  for (final c in resolved) {
    if (c.role == 'todo') return c;
  }
  return resolved.isNotEmpty ? resolved.first : null;
}

Color columnAccent(KanbanColumn column) {
  final parsed = parseHexColor(column.color);
  if (parsed != null) return parsed;
  return kanbanColumnAccents[column.key] ?? const Color(0xFF6366F1);
}

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final n = int.tryParse(value, radix: 16);
  if (n == null) return null;
  return Color(n);
}

KanbanPriorityMeta priorityMeta(String? priority) {
  final p = priority ?? 'none';
  return kanbanPriorities.firstWhere(
    (x) => x.value == p,
    orElse: () => kanbanPriorities.first,
  );
}

String columnLabel(List<KanbanColumn> columns, String status) {
  for (final c in columns) {
    if (c.key == status) return c.label;
  }
  return status;
}

Map<String, List<KanbanTask>> groupTasksByColumn(
  List<KanbanTask> tasks,
  List<KanbanColumn> columns,
) {
  final resolved = resolveBoardColumns(columns);
  final map = {for (final c in resolved) c.key: <KanbanTask>[]};
  for (final task in tasks) {
    (map[task.status] ??= []).add(task);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.position.compareTo(b.position));
  }
  return map;
}
