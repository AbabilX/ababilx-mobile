import 'package:flutter/material.dart';

/// Round upload progress with a cross in the middle.
///
/// Sits on the file preview, the way a photo bubble carries its own control.
/// On a photo the ink is white: the picture is not a themed surface, same
/// exception as the time row drawn on media.
class PendingUploadRing extends StatelessWidget {
  const PendingUploadRing({
    super.key,
    required this.progress,
    required this.label,
    required this.onPhoto,
    this.onCancel,
  });

  static const ringKey = Key('pending-upload-ring');
  static const diameter = 56.0;

  final double? progress;
  final String label;
  final bool onPhoto;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = onPhoto ? Colors.white : scheme.onSurface;
    final disc = onPhoto
        ? scheme.scrim.withValues(alpha: 0.45)
        : scheme.surface.withValues(alpha: 0.92);
    final value = progress == null || progress! <= 0
        ? null
        : progress!.clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: disc,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ringKey,
          customBorder: const CircleBorder(),
          onTap: onCancel,
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 2.5,
                    color: ink,
                    backgroundColor: ink.withValues(alpha: 0.28),
                  ),
                ),
                Icon(Icons.close_rounded, size: 22, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
