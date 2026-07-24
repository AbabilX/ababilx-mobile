import '../data/models/crm_models.dart';

String buildFollowupsCsv(List<CrmFollowup> followups) {
  String esc(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  const headers = [
    'Contact',
    'Phone',
    'Company',
    'Scheduled',
    'Type',
    'Assignee',
    'Priority',
    'Status',
  ];
  final rows = [
    for (final f in followups)
      [
        f.contactName ?? '',
        f.contactPhone ?? '',
        f.contactCompany ?? '',
        f.scheduledAt,
        f.activityTypeName ?? '',
        f.assigneeName ?? '',
        f.priority,
        f.status,
      ],
  ];
  return [
    headers.map(esc).join(','),
    for (final r in rows) r.map(esc).join(','),
  ].join('\n');
}
