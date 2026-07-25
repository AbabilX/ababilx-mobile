import '../data/models/crm_models.dart';

enum StageMoveKind { forward, backward, lost }

/// Web `stage-transition-rules.ts` — only ±1 stage or Lost.
StageMoveKind? stageMoveKind(
  CrmLead lead,
  List<CrmStage> stages,
  CrmStage target,
) {
  final currentIndex = stages.indexWhere((s) => s.id == lead.stageId);
  final targetIndex = stages.indexWhere((s) => s.id == target.id);
  if (currentIndex < 0 || targetIndex < 0 || currentIndex == targetIndex) {
    return null;
  }
  if (target.isLost) return StageMoveKind.lost;
  if (targetIndex == currentIndex + 1) return StageMoveKind.forward;
  if (targetIndex == currentIndex - 1) return StageMoveKind.backward;
  return null;
}

String? stageDisabledReason(
  CrmLead lead,
  List<CrmStage> stages,
  CrmStage target,
) {
  if (target.id == lead.stageId) return 'Current stage';
  if (stageMoveKind(lead, stages, target) != null) return null;
  return 'Move one stage at a time';
}
