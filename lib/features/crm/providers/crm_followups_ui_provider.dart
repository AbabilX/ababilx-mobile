import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/followup_buckets.dart';

enum FollowupScope { mine, all }

class CrmFollowupsUiState {
  const CrmFollowupsUiState({
    this.scope = FollowupScope.mine,
    this.schedule = FollowupSchedule.all,
    this.addTick = 0,
    this.searchQuery = '',
    this.mineCount = 0,
    this.allCount = 0,
    this.canCreate = false,
    this.formSheetOpen = false,
  });

  final FollowupScope scope;
  final FollowupSchedule schedule;
  final int addTick;
  final String searchQuery;
  final int mineCount;
  final int allCount;
  final bool canCreate;
  final bool formSheetOpen;

  CrmFollowupsUiState copyWith({
    FollowupScope? scope,
    FollowupSchedule? schedule,
    int? addTick,
    String? searchQuery,
    int? mineCount,
    int? allCount,
    bool? canCreate,
    bool? formSheetOpen,
  }) {
    return CrmFollowupsUiState(
      scope: scope ?? this.scope,
      schedule: schedule ?? this.schedule,
      addTick: addTick ?? this.addTick,
      searchQuery: searchQuery ?? this.searchQuery,
      mineCount: mineCount ?? this.mineCount,
      allCount: allCount ?? this.allCount,
      canCreate: canCreate ?? this.canCreate,
      formSheetOpen: formSheetOpen ?? this.formSheetOpen,
    );
  }
}

class CrmFollowupsUiNotifier extends Notifier<CrmFollowupsUiState> {
  @override
  CrmFollowupsUiState build() => const CrmFollowupsUiState();

  void setScope(FollowupScope scope) {
    if (state.scope == scope) return;
    state = state.copyWith(scope: scope);
  }

  void setSchedule(FollowupSchedule schedule) {
    if (state.schedule == schedule) return;
    state = state.copyWith(schedule: schedule);
  }

  void requestAdd() {
    state = state.copyWith(addTick: state.addTick + 1);
  }

  void setSearchQuery(String q) {
    final next = q.trim();
    if (state.searchQuery == next) return;
    state = state.copyWith(searchQuery: next);
  }

  void setFormSheetOpen(bool open) {
    if (state.formSheetOpen == open) return;
    state = state.copyWith(formSheetOpen: open);
  }

  void syncMeta({
    required int mineCount,
    required int allCount,
    required bool canCreate,
  }) {
    if (state.mineCount == mineCount &&
        state.allCount == allCount &&
        state.canCreate == canCreate) {
      return;
    }
    state = state.copyWith(
      mineCount: mineCount,
      allCount: allCount,
      canCreate: canCreate,
    );
  }
}

final crmFollowupsUiProvider =
    NotifierProvider<CrmFollowupsUiNotifier, CrmFollowupsUiState>(
  CrmFollowupsUiNotifier.new,
);
