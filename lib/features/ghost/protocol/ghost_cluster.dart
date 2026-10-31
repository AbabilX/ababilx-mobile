import '../../messages/chat_utils.dart';
import '../providers/ghost_state.dart';

/// Where an item sits in a run of messages, so the bubbles collapse their
/// facing corners the way the ordinary timeline's do.
///
/// The reference app's rule, and the same one `chatMessageClusterPosition`
/// applies: the same sender, both plain text, inside the same minute. A file
/// breaks a run — it is a tile, not a line of text, and collapsing a corner
/// against it reads as a rendering fault.
MessageClusterPosition ghostClusterPosition(
  GhostItem? previous,
  GhostItem current,
  GhostItem? next,
) {
  final joinsPrevious = _canCluster(previous, current);
  final joinsNext = _canCluster(current, next);
  if (joinsPrevious && joinsNext) return MessageClusterPosition.middle;
  if (joinsNext) return MessageClusterPosition.start;
  if (joinsPrevious) return MessageClusterPosition.end;
  return MessageClusterPosition.single;
}

bool _canCluster(GhostItem? previous, GhostItem? current) {
  if (previous == null || current == null) return false;
  if (previous.fromMe != current.fromMe) return false;
  if (previous.isFile || current.isFile) return false;
  return previous.at.year == current.at.year &&
      previous.at.month == current.at.month &&
      previous.at.day == current.at.day &&
      previous.at.hour == current.at.hour &&
      previous.at.minute == current.at.minute;
}
