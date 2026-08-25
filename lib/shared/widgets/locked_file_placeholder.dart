import 'package:flutter/material.dart';

/// Non-interactive stand-in for a team file whose workspace has passed the
/// free-plan retention lock. Never resolves a network request for the file —
/// backend already blanks `file_url` for locked attachments, so this widget
/// is the only thing allowed to render in its place.
class LockedFilePlaceholder extends StatelessWidget {
  const LockedFilePlaceholder({
    super.key,
    required this.fileName,
    this.compact = true,
  });

  final String fileName;

  /// true: small chip (fits inline with image/video grids).
  /// false: full-width list-tile style row (documents, comments).
  final bool compact;

  void _explain(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This file is locked — the workspace passed the free plan file limit. Upgrade to unlock it.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (compact) {
      return Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _explain(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    fileName.isEmpty ? 'Locked file' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _explain(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName.isEmpty ? 'Locked file' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                'Locked',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
