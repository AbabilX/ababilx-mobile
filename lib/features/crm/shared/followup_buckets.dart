import '../data/models/crm_models.dart';

enum FollowupSchedule {
  all,
  today,
  overdue,
  tomorrow,
  week,
  completed,
}

bool isFollowupOverdue(CrmFollowup f) {
  if (f.status != 'pending') return false;
  final d = DateTime.tryParse(f.scheduledAt)?.toLocal();
  if (d == null) return false;
  final now = DateTime.now();
  final startToday = DateTime(now.year, now.month, now.day);
  return d.isBefore(startToday);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool matchesFollowupSchedule(CrmFollowup f, FollowupSchedule tab) {
  final d = DateTime.tryParse(f.scheduledAt)?.toLocal();
  if (d == null) return tab == FollowupSchedule.all;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final weekEnd = today.add(const Duration(days: 7));

  switch (tab) {
    case FollowupSchedule.all:
      return true;
    case FollowupSchedule.today:
      return f.status == 'pending' && _isSameDay(d, today);
    case FollowupSchedule.overdue:
      return isFollowupOverdue(f);
    case FollowupSchedule.tomorrow:
      return f.status == 'pending' && _isSameDay(d, tomorrow);
    case FollowupSchedule.week:
      return f.status == 'pending' &&
          !d.isBefore(today) &&
          d.isBefore(weekEnd);
    case FollowupSchedule.completed:
      return f.status == 'done';
  }
}

bool isMineFollowup(CrmFollowup f, String myId) {
  if (myId.isEmpty) return false;
  return f.assignedUserId == myId || f.createdBy == myId;
}

String followupStatusLabel(CrmFollowup f) {
  if (f.status == 'done') return 'Completed';
  if (f.status == 'cancelled') return 'Cancelled';
  if (isFollowupOverdue(f)) return 'Overdue';
  return 'Pending';
}

/// Stub lead for edit/create sheets when full lead isn't loaded.
CrmLead leadStubFromFollowup(CrmFollowup f) => CrmLead(
      id: f.leadId,
      teamId: '',
      contactId: f.contactId,
      title: (f.contactName ?? '').isNotEmpty ? f.contactName! : 'Lead',
      ownerName: f.assigneeName,
    );
