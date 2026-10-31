import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/space_failure.dart';

/// Placeholder rail + rows while the first load runs with nothing saved.
class SpacesSkeleton extends StatelessWidget {
  const SpacesSkeleton({super.key, this.railOnly = false, this.rows = 9});

  final bool railOnly;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget block(double w, double h, double r) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    final list = ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      children: [
        block(140, 18, 6),
        const SizedBox(height: 24),
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                block(20, 20, 6),
                const SizedBox(width: 12),
                block(i.isEven ? 120 : 90, 14, 6),
              ],
            ),
          ),
      ],
    );
    if (railOnly) return list;
    return Row(
      key: const Key('spaces-skeleton'),
      children: [
        Container(
          width: 72,
          color: c.surfaceContainerLow,
          child: Column(
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: block(48, 48, 24),
                ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}

/// Full panel when a load failed and nothing is saved. Always has Retry.
class SpacesErrorView extends StatelessWidget {
  const SpacesErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.busy = false,
  });

  final SpaceFailure failure;
  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = spaceFailureCopy(failure);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: failure == SpaceFailure.offline
                  ? HugeIcons.strokeRoundedWifiOff01
                  : HugeIcons.strokeRoundedServerStack01,
              color: theme.colorScheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              copy.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              copy.subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: busy ? null : onRetry,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A slim notice over content drawn from the saved copy.
class SpacesBanner extends StatelessWidget {
  const SpacesBanner({
    super.key,
    required this.failure,
    required this.onRetry,
    this.busy = false,
  });

  final SpaceFailure failure;
  final VoidCallback onRetry;
  final bool busy;

  static String text(SpaceFailure f) => switch (f) {
    SpaceFailure.offline => "Can't reach Spaces · showing saved copy",
    SpaceFailure.unavailable => 'Spaces is unavailable · showing saved copy',
    _ => 'Could not refresh · showing saved copy',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Container(
      key: const Key('spaces-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: failure == SpaceFailure.offline
                ? HugeIcons.strokeRoundedWifiOff01
                : HugeIcons.strokeRoundedAlert02,
            color: c.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text(failure),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onRetry,
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
