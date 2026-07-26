import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrmOrganizationsUiState {
  const CrmOrganizationsUiState({
    this.addTick = 0,
    this.searchTick = 0,
    this.canCreate = false,
    this.formSheetOpen = false,
  });

  final int addTick;
  final int searchTick;
  final bool canCreate;
  final bool formSheetOpen;

  CrmOrganizationsUiState copyWith({
    int? addTick,
    int? searchTick,
    bool? canCreate,
    bool? formSheetOpen,
  }) {
    return CrmOrganizationsUiState(
      addTick: addTick ?? this.addTick,
      searchTick: searchTick ?? this.searchTick,
      canCreate: canCreate ?? this.canCreate,
      formSheetOpen: formSheetOpen ?? this.formSheetOpen,
    );
  }
}

class CrmOrganizationsUiNotifier extends Notifier<CrmOrganizationsUiState> {
  @override
  CrmOrganizationsUiState build() => const CrmOrganizationsUiState();

  void requestAdd() {
    state = state.copyWith(addTick: state.addTick + 1);
  }

  void requestSearch() {
    state = state.copyWith(searchTick: state.searchTick + 1);
  }

  void setCanCreate(bool canCreate) {
    if (state.canCreate == canCreate) return;
    state = state.copyWith(canCreate: canCreate);
  }

  void setFormSheetOpen(bool open) {
    if (state.formSheetOpen == open) return;
    state = state.copyWith(formSheetOpen: open);
  }
}

final crmOrganizationsUiProvider =
    NotifierProvider<CrmOrganizationsUiNotifier, CrmOrganizationsUiState>(
      CrmOrganizationsUiNotifier.new,
    );
