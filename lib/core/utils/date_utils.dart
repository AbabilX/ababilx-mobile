import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class AppDateUtils {
  AppDateUtils._();

  static String formatSentAt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 7) return timeago.format(dt);
    return DateFormat('MMM d, yyyy · h:mm a').format(dt.toLocal());
  }

  static String formatSendTime(String time24, String timezone) {
    // time24 = "HH:MM" → "9:00 AM (Asia/Dhaka)"
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2000, 1, 1, hour, minute);
      final formatted = DateFormat('h:mm a').format(dt);
      final tz = timezone.split('/').last.replaceAll('_', ' ');
      return '$formatted ($tz)';
    } catch (_) {
      return '$time24 ($timezone)';
    }
  }

  static String formatDays(List<int> days) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (days.isEmpty) return 'No days';
    return days.map((d) => names[d % 7]).join(', ');
  }

  static String minutesLabel(int? minutes) {
    if (minutes == null) return 'No notification';
    if (minutes == 60) return '1 hour before';
    return '$minutes min before';
  }
}
