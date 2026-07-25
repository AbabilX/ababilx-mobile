import 'package:equatable/equatable.dart';

class CrmStageCount extends Equatable {
  const CrmStageCount({
    required this.stageId,
    required this.name,
    this.color = '',
    this.count = 0,
    this.value = 0,
  });

  final String stageId;
  final String name;
  final String color;
  final int count;
  final double value;

  factory CrmStageCount.fromJson(Map<String, dynamic> json) => CrmStageCount(
    stageId: json['stage_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    color: json['color'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    value: (json['value'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [stageId, count, value];
}

/// `GET /api/teams/crm/dashboard` payload (hub charts use money + stages).
class CrmDashboard extends Equatable {
  const CrmDashboard({
    this.totalContacts = 0,
    this.pipelineValue = 0,
    this.wonValue = 0,
    this.stageCounts = const [],
    this.followupsDue = 0,
    this.followupsOverdue = 0,
  });

  final int totalContacts;
  final double pipelineValue;
  final double wonValue;
  final List<CrmStageCount> stageCounts;
  final int followupsDue;
  final int followupsOverdue;

  factory CrmDashboard.fromJson(Map<String, dynamic> json) => CrmDashboard(
    totalContacts: (json['total_contacts'] as num?)?.toInt() ?? 0,
    pipelineValue: (json['pipeline_value'] as num?)?.toDouble() ?? 0,
    wonValue: (json['won_value'] as num?)?.toDouble() ?? 0,
    stageCounts: (json['stage_counts'] as List<dynamic>? ?? [])
        .map((e) => CrmStageCount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    followupsDue: (json['followups_due'] as num?)?.toInt() ?? 0,
    followupsOverdue: (json['followups_overdue'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [
    totalContacts,
    pipelineValue,
    wonValue,
    stageCounts,
  ];
}
