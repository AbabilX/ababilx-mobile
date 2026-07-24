import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shell-facing wall UI flags (composer sheet open → hide bottom pills).
class WallUiState {
  const WallUiState({this.composerSheetOpen = false});

  final bool composerSheetOpen;

  WallUiState copyWith({bool? composerSheetOpen}) => WallUiState(
        composerSheetOpen: composerSheetOpen ?? this.composerSheetOpen,
      );
}

class WallUiNotifier extends Notifier<WallUiState> {
  @override
  WallUiState build() => const WallUiState();

  void setComposerSheetOpen(bool open) {
    if (state.composerSheetOpen == open) return;
    state = state.copyWith(composerSheetOpen: open);
  }
}

final wallUiProvider =
    NotifierProvider<WallUiNotifier, WallUiState>(WallUiNotifier.new);
