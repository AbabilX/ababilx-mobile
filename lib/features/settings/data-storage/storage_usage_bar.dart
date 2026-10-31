import 'package:flutter/material.dart';

import '../../../shared/text/byte_size.dart';
import '../../attachments/storage/storage_usage.dart';

/// One stacked bar plus a legend — the reference app's storage breakdown.
///
/// A bar rather than a pie: the interesting comparison is "video against
/// everything else", which a length answers at a glance and an angle does not.
class StorageUsageBar extends StatelessWidget {
  const StorageUsageBar({super.key, required this.usage});

  final StorageUsage usage;

  static const _colors = {
    StorageBucket.photos: Color(0xFF6366F1),
    StorageBucket.videos: Color(0xFF22C55E),
    StorageBucket.audio: Color(0xFFF59E0B),
    StorageBucket.documents: Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final occupied = usage.occupied;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatBytes(usage.total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            usage.isEmpty
                ? 'Nothing downloaded on this phone yet'
                : '${usage.count} files kept on this phone',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: usage.isEmpty
                  ? ColoredBox(color: colors.surfaceContainerHighest)
                  : Row(
                      children: [
                        for (final bucket in occupied)
                          Expanded(
                            // Integer flex, so a bucket that rounds to zero
                            // still shows as a hairline rather than vanishing.
                            flex: (usage.bytesFor(bucket) * 1000 ~/ usage.total)
                                .clamp(1, 1000),
                            child: ColoredBox(color: _colors[bucket]!),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              for (final bucket in occupied)
                _Legend(
                  color: _colors[bucket]!,
                  label: bucket.label,
                  value: formatBytes(usage.bytesFor(bucket)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
