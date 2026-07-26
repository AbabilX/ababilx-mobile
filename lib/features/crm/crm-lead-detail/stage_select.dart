import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_hex_color.dart';
import '../shared/stage_chip.dart';
import 'stage_transition_rules.dart';
import 'stage_transition_sheet.dart';

/// Compact stage chip → pick adjacent/lost stage then transition sheet.
class LeadStageSelect extends ConsumerWidget {
  const LeadStageSelect({
    super.key,
    required this.lead,
    required this.stages,
    required this.canEdit,
    this.onTransitionCompleted,
  });

  final CrmLead lead;
  final List<CrmStage> stages;
  final bool canEdit;
  final VoidCallback? onTransitionCompleted;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    if (!canEdit || stages.isEmpty) return;
    final chosen = await showModalBottomSheet<CrmStage>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Move to stage',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final s in stages)
                Builder(
                  builder: (context) {
                    final reason = stageDisabledReason(lead, stages, s);
                    final locked = reason != null && s.id != lead.stageId;
                    final isCurrent = s.id == lead.stageId;
                    return ListTile(
                      enabled: !locked || isCurrent,
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.isLost
                              ? const Color(0xFFEF4444)
                              : (parseCrmHex(s.color) ?? colors.primary),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(s.name),
                      subtitle: locked
                          ? Text(reason)
                          : (isCurrent ? const Text('Current stage') : null),
                      trailing: isCurrent
                          ? Icon(
                              Icons.check_rounded,
                              color: s.isLost
                                  ? const Color(0xFFEF4444)
                                  : (parseCrmHex(s.color) ?? colors.primary),
                            )
                          : (locked
                                ? Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  )
                                : null),
                      onTap: locked || isCurrent
                          ? null
                          : () => Navigator.pop(ctx, s),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || chosen.id == lead.stageId || !context.mounted) return;
    final moved = await showStageTransitionSheet(
      context,
      ref: ref,
      lead: lead,
      stages: stages,
      target: chosen,
    );
    if (moved && context.mounted) onTransitionCompleted?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = (lead.stageName ?? '').isEmpty
        ? 'Set stage'
        : lead.stageName!;
    final chip = StageChip(
      name: label,
      colorHex: lead.isLost ? '#EF4444' : lead.stageColor,
      showChevron: canEdit && stages.isNotEmpty,
    );

    if (!canEdit || stages.isEmpty) return chip;

    return InkWell(
      onTap: () => _pick(context, ref),
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
