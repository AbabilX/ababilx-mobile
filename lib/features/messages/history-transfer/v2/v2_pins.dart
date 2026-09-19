/// Attachment files a running transfer still has to read.
///
/// The attachment sweeper evicts cold files to stay inside its disk budget.
/// A file planned into a transfer must survive until its bytes have left, or
/// the upload would find it gone and have to send it as omitted. The sweeper
/// asks [isHeld] before evicting; a foreground-only transfer means an
/// in-memory set is enough — when the process dies, the transfer pauses too,
/// and resuming holds the files again before any upload.
class V2Pins {
  V2Pins._();

  static final Set<String> _held = {};

  static void hold(Iterable<String> urlKeys) => _held.addAll(urlKeys);

  static void release() => _held.clear();

  static bool isHeld(String urlKey) => _held.contains(urlKey);
}
