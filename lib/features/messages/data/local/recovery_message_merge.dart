import '../models/chat_message.dart';

/// Unknown (zero) revisions are not "oldest". With an unknown ordering an
/// archive keeps the live device copy; a server page is the current authority.
bool keepLocalDuringRecovery(
  ChatMessage current,
  ChatMessage incoming, {
  required bool fromBackup,
}) {
  if (incoming.contentPurged && !current.contentPurged) return true;
  if (current.isDeleted && !incoming.isDeleted) return true;
  if (current.revision > 0 && incoming.revision > 0) {
    return current.revision >= incoming.revision;
  }
  return fromBackup;
}
