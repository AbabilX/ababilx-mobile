import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shell-facing wall UI flags (sheets open → hide bottom pills).
class WallUiState {
  const WallUiState({
    this.composerSheetOpen = false,
    this.reactionSheetOpen = false,
    this.forwardSheetOpen = false,
    this.postActionsSheetOpen = false,
  });

  final bool composerSheetOpen;
  final bool reactionSheetOpen;
  final bool forwardSheetOpen;
  final bool postActionsSheetOpen;

  bool get hideBottomBar =>
      composerSheetOpen ||
      reactionSheetOpen ||
      forwardSheetOpen ||
      postActionsSheetOpen;

  WallUiState copyWith({
    bool? composerSheetOpen,
    bool? reactionSheetOpen,
    bool? forwardSheetOpen,
    bool? postActionsSheetOpen,
  }) => WallUiState(
    composerSheetOpen: composerSheetOpen ?? this.composerSheetOpen,
    reactionSheetOpen: reactionSheetOpen ?? this.reactionSheetOpen,
    forwardSheetOpen: forwardSheetOpen ?? this.forwardSheetOpen,
    postActionsSheetOpen: postActionsSheetOpen ?? this.postActionsSheetOpen,
  );
}

class WallUiNotifier extends Notifier<WallUiState> {
  @override
  WallUiState build() => const WallUiState();

  void setComposerSheetOpen(bool open) {
    if (state.composerSheetOpen == open) return;
    state = state.copyWith(composerSheetOpen: open);
  }

  void setReactionSheetOpen(bool open) {
    if (state.reactionSheetOpen == open) return;
    state = state.copyWith(reactionSheetOpen: open);
  }

  void setForwardSheetOpen(bool open) {
    if (state.forwardSheetOpen == open) return;
    state = state.copyWith(forwardSheetOpen: open);
  }

  void setPostActionsSheetOpen(bool open) {
    if (state.postActionsSheetOpen == open) return;
    state = state.copyWith(postActionsSheetOpen: open);
  }
}

final wallUiProvider = NotifierProvider<WallUiNotifier, WallUiState>(
  WallUiNotifier.new,
);
