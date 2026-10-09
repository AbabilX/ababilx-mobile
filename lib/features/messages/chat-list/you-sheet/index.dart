import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/providers/profile_provider.dart';
import 'you_identity.dart';
import 'you_menu.dart';
import 'you_sheet_action.dart';

import 'dart:ui';

Future<YouSheetAction?> showYouSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);

  return navigator.push<YouSheetAction>(
    _BlurredModalBottomSheetRoute<YouSheetAction>(
      builder: (_) => const YouSheet(),
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      modalBarrierColor: Colors.black.withValues(alpha: 0.18),
      barrierFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
    ),
  );
}

class _BlurredModalBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _BlurredModalBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.isScrollControlled = false,
    super.scrollControlDisabledMaxHeightRatio,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.isDismissible = true,
    super.modalBarrierColor,
    super.enableDrag = true,
    super.showDragHandle,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = false,
    super.sheetAnimationStyle,
    super.requestFocus,
    this.barrierFilter,
  });

  final ImageFilter? barrierFilter;

  @override
  ImageFilter? get filter => barrierFilter;
}

class YouSheet extends ConsumerWidget {
  const YouSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final user = ref.watch(profileProvider).valueOrNull;
    final name = user?.name.isNotEmpty == true ? user!.name : 'You';
    final avatar = user?.avatarUrl;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              YouIdentity(
                name: name,
                currentUserId: user?.id ?? '',
                avatarUrl: avatar,
              ),
              const SizedBox(height: 4),
              Divider(
                height: 1,
                thickness: 0.5,
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 8),
              const YouMenu(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
