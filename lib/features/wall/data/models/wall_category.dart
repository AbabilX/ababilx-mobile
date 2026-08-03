import 'package:equatable/equatable.dart';

class WallCategory extends Equatable {
  const WallCategory({
    required this.id,
    required this.teamId,
    required this.slug,
    required this.label,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String teamId;
  final String slug;
  final String label;
  final String? description;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory WallCategory.fromJson(Map<String, dynamic> json) => WallCategory(
    id: json['id'] as String? ?? '',
    teamId: json['team_id'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    label: json['label'] as String? ?? '',
    description: json['description'] as String?,
    status: json['status'] as String? ?? 'published',
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
  );

  @override
  List<Object?> get props => [id, slug, label];
}
