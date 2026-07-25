import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_dates.dart';
import 'stage_step_item.dart';
import 'stage_transition_rules.dart';
import 'stage_transition_sheet.dart';

/// Horizontal pipeline stepper — adjacent/lost only + transition sheet.
class LeadStageStepper extends ConsumerStatefulWidget {
  const LeadStageStepper({
    super.key,
    required this.lead,
    required this.stages,
    required this.events,
    required this.canEdit,
  });

  final CrmLead lead;
  final List<CrmStage> stages;
  final List<CrmTimelineEvent> events;
  final bool canEdit;

  @override
  ConsumerState<LeadStageStepper> createState() => _LeadStageStepperState();
}

class _LeadStageStepperState extends ConsumerState<LeadStageStepper> {
  var _busy = false;

  Future<void> _move(CrmStage stage) async {
    if (!widget.canEdit || _busy) return;
    if (stage.id == widget.lead.stageId) return;
    if (stageMoveKind(widget.lead, widget.stages, stage) == null) return;
    setState(() => _busy = true);
    try {
      await showStageTransitionSheet(
        context,
        ref: ref,
        lead: widget.lead,
        stages: widget.stages,
        target: stage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;
    if (stages.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final currentIdx = stages.indexWhere((s) => s.id == widget.lead.stageId);
    final dates = deriveStageDates(widget.lead, stages, widget.events);
    final lost = widget.lead.isLost;

    StageStepState stateOf(int i) {
      if (i == currentIdx) return StageStepState.current;
      // Lost jump: don't paint skipped stages as done (web honesty).
      if (lost) return StageStepState.upcoming;
      if (currentIdx >= 0 && i < currentIdx) return StageStepState.done;
      return StageStepState.upcoming;
    }

    return Material(
      color: colors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Container(
                    width: 28,
                    height: 2,
                    color: !lost && currentIdx >= 0 && i <= currentIdx
                        ? colors.tertiary
                        : colors.outlineVariant,
                  ),
                ),
              StageStepItem(
                stage: stages[i],
                state: stateOf(i),
                date: stateOf(i) != StageStepState.upcoming
                    ? formatCrmDate(dates[stages[i].id] ?? '')
                    : null,
                clickable: widget.canEdit &&
                    stageMoveKind(widget.lead, stages, stages[i]) != null,
                disabled: _busy,
                onTap: () => _move(stages[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
