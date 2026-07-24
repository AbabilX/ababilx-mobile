import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ContactScope { mine, all }

class CrmContactsUiState {
  const CrmContactsUiState({
    this.scope = ContactScope.mine,
    this.addTick = 0,
    this.mineCount = 0,
    this.allCount = 0,
    this.canCreate = false,
  });

  final ContactScope scope;
  final int addTick;
  final int mineCount;
  final int allCount;
  final bool canCreate;

  CrmContactsUiState copyWith({
    ContactScope? scope,
    int? addTick,
    int? mineCount,
    int? allCount,
    bool? canCreate,
  }) {
    return CrmContactsUiState(
      scope: scope ?? this.scope,
      addTick: addTick ?? this.addTick,
      mineCount: mineCount ?? this.mineCount,
      allCount: allCount ?? this.allCount,
      canCreate: canCreate ?? this.canCreate,
    );
  }
}

class CrmContactsUiNotifier extends Notifier<CrmContactsUiState> {
  @override
  CrmContactsUiState build() => const CrmContactsUiState();

  void setScope(ContactScope scope) {
    if (state.scope == scope) return;
    state = state.copyWith(scope: scope);
  }

  void requestAdd() {
    state = state.copyWith(addTick: state.addTick + 1);
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

final crmContactsUiProvider =
    NotifierProvider<CrmContactsUiNotifier, CrmContactsUiState>(
  CrmContactsUiNotifier.new,
);
