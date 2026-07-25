import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';

class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key, required this.events, this.shrinkWrap = false});

  final List<CrmTimelineEvent> events;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const CrmEmpty(message: 'No timeline events yet.');
    }

    final groups = <String, List<CrmTimelineEvent>>{};
    final order = <String>[];
    for (final e in events) {
      final key = formatCrmDate(e.createdAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(e);
    }

    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: order.length,
      itemBuilder: (_, gi) {
        final day = order[gi];
        final items = groups[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: gi == 0 ? 0 : 16, bottom: 8),
              child: Text(
                day,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if ((e.actorName ?? '').isNotEmpty) e.actorName!,
                              formatCrmDateTime(e.createdAt),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
