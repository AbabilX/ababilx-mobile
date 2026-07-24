import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_hex_color.dart';
import '../shared/stage_chip.dart';

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
                  trailing: s.id == lead.stageId
                      ? Icon(
                          Icons.check_rounded,
                          color: s.isLost
                              ? const Color(0xFFEF4444)
                              : (parseCrmHex(s.color) ?? colors.primary),
                        )
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
    final label = (lead.stageName ?? '').isEmpty ? 'Set stage' : lead.stageName!;
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
