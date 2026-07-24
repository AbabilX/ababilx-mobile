import '../data/models/crm_models.dart';

/// When each stage was last reached (web `deriveStageDates`).
Map<String, String> deriveStageDates(
  CrmLead lead,
  List<CrmStage> stages,
  List<CrmTimelineEvent> events,
) {
  final byName = {for (final s in stages) s.name: s.id};
  final dates = <String, String>{};

  for (var i = events.length - 1; i >= 0; i--) {
    final e = events[i];
    if (e.kind != 'stage_changed') continue;
    final id = e.toStageId ?? _destinationStageId(e.summary, byName);
    if (id != null && id.isNotEmpty) dates[id] = e.createdAt;
  }

  final sid = lead.stageId;
  if (sid != null && sid.isNotEmpty && !dates.containsKey(sid)) {
    dates[sid] = lead.createdAt;
  }
  return dates;
}

String? _destinationStageId(String summary, Map<String, String> byName) {
  final arrow = summary.lastIndexOf(' → ');
  if (arrow >= 0) {
    return byName[summary.substring(arrow + 3).trim()];
  }
  if (summary.startsWith('Moved to ')) {
    return byName[summary.substring('Moved to '.length).trim()];
  }
  return null;
}

String formatCrmDate(String iso) {
  if (iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String formatCrmDateTime(String iso) {
  if (iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '${d.year}-$m-$day $h:$min';
}
