import 'package:equatable/equatable.dart';

/// Hit from `GET /api/teams/crm/search`.
class CrmSearchHit extends Equatable {
  const CrmSearchHit({
    required this.kind,
    required this.id,
    this.contactId = '',
    this.contactName = '',
    this.title = '',
    this.snippet = '',
    this.createdAt = '',
  });

  final String kind;
  final String id;
  final String contactId;
  final String contactName;
  final String title;
  final String snippet;
  final String createdAt;

  factory CrmSearchHit.fromJson(Map<String, dynamic> json) => CrmSearchHit(
        kind: json['kind'] as String? ?? '',
        id: json['id'] as String? ?? '',
        contactId: json['contact_id'] as String? ?? '',
        contactName: json['contact_name'] as String? ?? '',
        title: json['title'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );

  String get typeBadge => switch (kind) {
        'contact' => 'Contact',
        'followup' => 'Follow-up',
        'note' => 'Note',
        'activity' => 'Activity',
        'timeline' => 'Update',
        _ => kind,
      };

  @override
  List<Object?> get props => [kind, id];
}
