import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import 'stage_step_item.dart';

/// Horizontal pipeline stepper — tap moves stage (web StageStepper).
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
    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).updateLeadStage(
            widget.lead.id,
            stageId: stage.id,
            pipelineId: widget.lead.pipelineId,
          );
      invalidateLeadDetail(ref, widget.lead.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to ${stage.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
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

    StageStepState stateOf(int i) {
      if (i == currentIdx) return StageStepState.current;
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
                    color: currentIdx >= 0 && i <= currentIdx
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
                clickable: widget.canEdit,
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
