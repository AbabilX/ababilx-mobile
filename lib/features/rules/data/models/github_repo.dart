import 'package:equatable/equatable.dart';

class GitHubRepo extends Equatable {
  const GitHubRepo({
    required this.id,
    required this.name,
    required this.fullName,
    required this.private,
  });

  final int id;
  final String name;
  final String fullName;
  final bool private;

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        private: json['private'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, fullName];
}
