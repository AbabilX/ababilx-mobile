import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LeadScope { mine, all }

class CrmLeadsUiState {
  const CrmLeadsUiState({
    this.scope = LeadScope.mine,
    this.addTick = 0,
    this.searchQuery = '',
    this.mineCount = 0,
    this.allCount = 0,
    this.canCreate = false,
    this.formSheetOpen = false,
  });

  final LeadScope scope;
  final int addTick;
  final String searchQuery;
  final int mineCount;
  final int allCount;
  final bool canCreate;

  /// When true, shell hides the floating bottom bar instantly.
  final bool formSheetOpen;

  CrmLeadsUiState copyWith({
    LeadScope? scope,
    int? addTick,
    String? searchQuery,
    int? mineCount,
    int? allCount,
    bool? canCreate,
    bool? formSheetOpen,
  }) {
    return CrmLeadsUiState(
      scope: scope ?? this.scope,
      addTick: addTick ?? this.addTick,
      searchQuery: searchQuery ?? this.searchQuery,
      mineCount: mineCount ?? this.mineCount,
      allCount: allCount ?? this.allCount,
      canCreate: canCreate ?? this.canCreate,
      formSheetOpen: formSheetOpen ?? this.formSheetOpen,
    );
  }
}

class CrmLeadsUiNotifier extends Notifier<CrmLeadsUiState> {
  @override
  CrmLeadsUiState build() => const CrmLeadsUiState();

  void setScope(LeadScope scope) {
    if (state.scope == scope) return;
    state = state.copyWith(scope: scope);
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

final crmLeadsUiProvider =
    NotifierProvider<CrmLeadsUiNotifier, CrmLeadsUiState>(
  CrmLeadsUiNotifier.new,
);
