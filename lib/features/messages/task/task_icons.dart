import 'package:hugeicons/hugeicons.dart';

import 'task_card_data.dart';

/// The Hugeicons glyph for each task value, so a priority or a status reads
/// by shape as well as by tint.
abstract final class TaskIcons {
  static const task = HugeIcons.strokeRoundedTask01;
  static const taskDone = HugeIcons.strokeRoundedTaskDone01;
  static const add = HugeIcons.strokeRoundedTaskAdd01;
  static const send = HugeIcons.strokeRoundedSent;
  static const photo = HugeIcons.strokeRoundedImage01;
  static const file = HugeIcons.strokeRoundedAttachment01;
  static const remove = HugeIcons.strokeRoundedCancel01;
  static const chevron = HugeIcons.strokeRoundedArrowDown01;
  static const picked = HugeIcons.strokeRoundedTick02;
  static const open = HugeIcons.strokeRoundedArrowRight01;

  static List<List<dynamic>> priority(TaskPriority p) => switch (p) {
    TaskPriority.low => HugeIcons.strokeRoundedFlag01,
    TaskPriority.medium => HugeIcons.strokeRoundedFlag01,
    TaskPriority.high => HugeIcons.strokeRoundedFlag02,
    TaskPriority.urgent => HugeIcons.strokeRoundedAlertCircle,
  };

  static List<List<dynamic>> status(TaskStatus s) => switch (s) {
    TaskStatus.todo => HugeIcons.strokeRoundedCircle,
    TaskStatus.inProgress => HugeIcons.strokeRoundedLoading03,
    TaskStatus.review => HugeIcons.strokeRoundedView,
    TaskStatus.blocked => HugeIcons.strokeRoundedUnavailable,
    TaskStatus.done => HugeIcons.strokeRoundedCheckmarkCircle02,
    TaskStatus.cancelled => HugeIcons.strokeRoundedCancelCircle,
  };
}
