import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'models/auto_commit_job.dart';

class AutoCommitRepository {
  const AutoCommitRepository(this._client);
  final ApiClient _client;

  Future<AutoCommitMeta> getJobs() async {
    final res = await _client.get(ApiConstants.jobs);
    final raw = res.data;
    final data = (raw is Map<String, dynamic> && raw.containsKey('data'))
        ? raw['data'] as Map<String, dynamic>
        : raw as Map<String, dynamic>;

    final jobsList = data['jobs'] as List? ?? [];
    final jobs = jobsList
        .map((e) => AutoCommitJob.fromJson(e as Map<String, dynamic>))
        .toList();

    final dayOptionsList = data['day_options'] as List? ?? [];
    final commitsOptionsList = data['commits_per_day_options'] as List? ?? [];

    return AutoCommitMeta(
      jobs: jobs,
      isPremium: data['is_premium'] as bool? ?? false,
      monthlyUsed: data['monthly_used'] as int? ?? 0,
      monthlyLimit: data['monthly_limit'] as int? ?? 3,
      maxDays: data['max_days'] as int? ?? 7,
      dayOptions: dayOptionsList.map((e) => e as int).toList(),
      commitsPerDayOptions: commitsOptionsList.map((e) => e as int).toList(),
    );
  }

  Future<AutoCommitJob> createJob({
    required int daysTotal,
    int commitsPerDay = 1,
    String? repoFullName,
  }) async {
    final body = <String, dynamic>{
      'days_total': daysTotal,
      'commits_per_day': commitsPerDay,
      if (repoFullName != null && repoFullName.isNotEmpty)
        'repo_full_name': repoFullName,
    };
    final res = await _client.post(ApiConstants.jobs, data: body);
    final raw = res.data;
    final data = (raw is Map<String, dynamic> && raw.containsKey('data'))
        ? raw['data']
        : raw;
    return AutoCommitJob.fromJson(data as Map<String, dynamic>);
  }

  Future<void> patchJob(String id, int commitsPerDay) async {
    await _client.patch(
      ApiConstants.jobById(id),
      data: {'commits_per_day': commitsPerDay},
    );
  }

  Future<void> deleteJob(String id) async {
    await _client.delete(ApiConstants.jobById(id));
  }
}

final autoCommitRepositoryProvider = Provider<AutoCommitRepository>(
  (ref) => AutoCommitRepository(ref.watch(apiClientProvider)),
);
