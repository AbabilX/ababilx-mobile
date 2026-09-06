import 'dart:ui';

import 'package:flutter/material.dart';

import 'message_vault_gate.dart';

/// Account-level message recovery presented over whichever primary page the
/// user landed on. The full-screen backdrop is part of the route so it blurs
/// the already-painted page behind the bottom sheet, not the sheet itself.
Future<void> showMessageVaultRecoverySheet({
  required BuildContext context,
  required VoidCallback onUnlocked,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: 'Message recovery',
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      final media = MediaQuery.of(sheetContext);
      final colors = Theme.of(sheetContext).colorScheme;
      final availableHeight = media.size.height - media.viewInsets.bottom;
      final slide = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return PopScope(
        canPop: false,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: animation,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: ColoredBox(
                        color: colors.scrim.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: SlideTransition(
                    position: slide,
                    child: Material(
                      color: colors.surface,
                      elevation: 12,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: availableHeight * 0.68,
                          child: MessageVaultGate(
                            onUnlocked: () {
                              onUnlocked();
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
