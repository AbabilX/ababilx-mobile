import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auto_commit_repository.dart';
import '../data/models/auto_commit_job.dart';

class AutoCommitNotifier extends AsyncNotifier<AutoCommitMeta> {
  @override
  Future<AutoCommitMeta> build() => _fetch();

  Future<AutoCommitMeta> _fetch() =>
      ref.read(autoCommitRepositoryProvider).getJobs();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<AutoCommitJob> createJob({
    required int daysTotal,
    int commitsPerDay = 1,
    String? repoFullName,
  }) async {
    final repo = ref.read(autoCommitRepositoryProvider);
    final job = await repo.createJob(
      daysTotal: daysTotal,
      commitsPerDay: commitsPerDay,
      repoFullName: repoFullName,
    );
    final meta = state.valueOrNull ?? AutoCommitMeta.empty();
    state = AsyncData(
      meta
          .copyWithJobs([job, ...meta.jobs])
          .withIncreasedUsage(daysTotal),
    );
    return job;
  }

  Future<void> patchJob(String id, int commitsPerDay) async {
    final repo = ref.read(autoCommitRepositoryProvider);
    final meta = state.valueOrNull ?? AutoCommitMeta.empty();
    final idx = meta.jobs.indexWhere((j) => j.id == id);
    if (idx == -1) return;

    // Optimistic update
    final updated = meta.jobs[idx].copyWith(commitsPerDay: commitsPerDay);
    final newJobs = [...meta.jobs]..[idx] = updated;
    state = AsyncData(meta.copyWithJobs(newJobs));

    try {
      await repo.patchJob(id, commitsPerDay);
    } catch (_) {
      // Revert
      state = AsyncData(meta);
      rethrow;
    }
  }

  Future<void> deleteJob(String id) async {
    await ref.read(autoCommitRepositoryProvider).deleteJob(id);
    final meta = state.valueOrNull ?? AutoCommitMeta.empty();
    state = AsyncData(
      meta.copyWithJobs(meta.jobs.where((j) => j.id != id).toList()),
    );
  }
}

final autoCommitProvider =
    AsyncNotifierProvider<AutoCommitNotifier, AutoCommitMeta>(
  AutoCommitNotifier.new,
);
