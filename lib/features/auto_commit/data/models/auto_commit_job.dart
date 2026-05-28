import 'package:equatable/equatable.dart';

class AutoCommitJob extends Equatable {
  const AutoCommitJob({
    required this.id,
    required this.userId,
    required this.repoFullName,
    required this.daysTotal,
    required this.daysDone,
    required this.commitsPerDay,
    required this.nextCommitDate,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String repoFullName;
  final int daysTotal;
  final int daysDone;
  final int commitsPerDay;
  final String nextCommitDate;
  final bool isActive;
  final DateTime createdAt;

  factory AutoCommitJob.fromJson(Map<String, dynamic> json) => AutoCommitJob(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        repoFullName: json['repo_full_name'] as String? ?? '',
        daysTotal: json['days_total'] as int? ?? 0,
        daysDone: json['days_done'] as int? ?? 0,
        commitsPerDay: json['commits_per_day'] as int? ?? 1,
        nextCommitDate: json['next_commit_date'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  AutoCommitJob copyWith({int? commitsPerDay}) => AutoCommitJob(
        id: id,
        userId: userId,
        repoFullName: repoFullName,
        daysTotal: daysTotal,
        daysDone: daysDone,
        commitsPerDay: commitsPerDay ?? this.commitsPerDay,
        nextCommitDate: nextCommitDate,
        isActive: isActive,
        createdAt: createdAt,
      );

  double get progress => daysTotal > 0 ? daysDone / daysTotal : 0.0;

  String get repoName {
    final parts = repoFullName.split('/');
    return parts.length >= 2 ? parts[1] : repoFullName;
  }

  @override
  List<Object?> get props => [id, userId, repoFullName, daysTotal, daysDone, commitsPerDay, nextCommitDate, isActive, createdAt];
}

class AutoCommitMeta {
  const AutoCommitMeta({
    required this.jobs,
    required this.isPremium,
    required this.monthlyUsed,
    required this.monthlyLimit,
    required this.maxDays,
    required this.dayOptions,
    required this.commitsPerDayOptions,
  });

  final List<AutoCommitJob> jobs;
  final bool isPremium;
  final int monthlyUsed;
  final int monthlyLimit;
  final int maxDays;
  final List<int> dayOptions;
  final List<int> commitsPerDayOptions;

  int get remaining => isPremium ? 999 : (monthlyLimit - monthlyUsed).clamp(0, monthlyLimit);
  bool get canCreate => isPremium || remaining > 0;

  factory AutoCommitMeta.empty() => const AutoCommitMeta(
        jobs: [],
        isPremium: false,
        monthlyUsed: 0,
        monthlyLimit: 3,
        maxDays: 7,
        dayOptions: [1, 2, 3, 4, 5, 6, 7],
        commitsPerDayOptions: [1, 2],
      );

  AutoCommitMeta copyWithJobs(List<AutoCommitJob> jobs) => AutoCommitMeta(
        jobs: jobs,
        isPremium: isPremium,
        monthlyUsed: monthlyUsed,
        monthlyLimit: monthlyLimit,
        maxDays: maxDays,
        dayOptions: dayOptions,
        commitsPerDayOptions: commitsPerDayOptions,
      );

  AutoCommitMeta withIncreasedUsage(int delta) => AutoCommitMeta(
        jobs: jobs,
        isPremium: isPremium,
        monthlyUsed: monthlyUsed + delta,
        monthlyLimit: monthlyLimit,
        maxDays: maxDays,
        dayOptions: dayOptions,
        commitsPerDayOptions: commitsPerDayOptions,
      );
}
