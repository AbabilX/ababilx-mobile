import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';

/// Compact stage chip → pick another stage (web StageSelect).
class LeadStageSelect extends ConsumerWidget {
  const LeadStageSelect({
    super.key,
    required this.lead,
    required this.stages,
    required this.canEdit,
  });

  final CrmLead lead;
  final List<CrmStage> stages;
  final bool canEdit;

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
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final s in stages)
                ListTile(
                  title: Text(s.name),
                  trailing: s.id == lead.stageId
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || chosen.id == lead.stageId) return;
    try {
      await ref.read(crmRepositoryProvider).updateLeadStage(
            lead.id,
            stageId: chosen.id,
            pipelineId: lead.pipelineId,
          );
      invalidateLeadDetail(ref, lead.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to ${chosen.name}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = (lead.stageName ?? '').isEmpty ? 'No stage' : lead.stageName!;
    return InkWell(
      onTap: canEdit ? () => _pick(context, ref) : null,
      borderRadius: BorderRadius.circular(999),
      child: ContactBadge(
        label: canEdit ? '$label ▾' : label,
        tone: lead.isWon
            ? ContactBadgeTone.tertiary
            : lead.isLost
                ? ContactBadgeTone.error
                : ContactBadgeTone.primary,
      ),
    );
  }
}
