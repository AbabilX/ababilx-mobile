import 'package:equatable/equatable.dart';

class KanbanBoard extends Equatable {
  const KanbanBoard({
    required this.id,
    required this.teamId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.memberIds = const [],
    this.columns = const [],
  });

  final String id;
  final String teamId;
  final String name;
  final String createdBy;
  final String createdAt;
  final List<String> memberIds;
  final List<KanbanColumn> columns;

  factory KanbanBoard.fromJson(Map<String, dynamic> json) => KanbanBoard(
        id: json['id'] as String,
        teamId: json['team_id'] as String,
        name: json['name'] as String? ?? 'Board',
        createdBy: json['created_by'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        memberIds: (json['member_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        columns: (json['columns'] as List<dynamic>?)
                ?.map((e) => KanbanColumn.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [id, name];
}

class KanbanColumn extends Equatable {
  const KanbanColumn({
    required this.id,
    required this.key,
    required this.label,
    required this.position,
    required this.color,
    required this.role,
  });

  final String id;
  final String key;
  final String label;
  final int position;
  final String color;
  final String role;

  factory KanbanColumn.fromJson(Map<String, dynamic> json) => KanbanColumn(
        id: json['id'] as String? ?? json['key'] as String? ?? '',
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        position: json['position'] as int? ?? 0,
        color: json['color'] as String? ?? '',
        role: json['role'] as String? ?? 'custom',
      );

  @override
  List<Object?> get props => [id, key, label];
}
