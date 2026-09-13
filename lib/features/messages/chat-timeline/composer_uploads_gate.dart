import 'dart:async';

/// The attachment uploads this composer still has in the air.
///
/// A tile now appears as soon as its URL is reserved, which is the whole point
/// — but it means the composer can hold an attachment whose object is not in
/// the bucket yet. Sending then would post a message pointing at nothing, and
/// every recipient would see a permanently broken photo. So the send path
/// awaits [settle] first: the message goes as soon as the bytes are there,
/// rather than the send button sitting dead while they travel.
///
/// [settle] loops because a run can finish while an earlier `await` is still
/// suspended — a rail tap during an album upload adds work after the wait
/// started.
class ComposerUploads {
  final _live = <Future<void>>{};

  bool get busy => _live.isNotEmpty;

  /// Follows one attach run. Failures are the caller's to report; they must
  /// not surface here as an unhandled error on a future nobody awaited.
  void track(Future<void> run) {
    final quiet = run.catchError((Object _) {});
    _live.add(quiet);
    quiet.whenComplete(() => _live.remove(quiet));
  }

  Future<void> settle() async {
    while (_live.isNotEmpty) {
      await Future.wait(_live.toList());
    }
  }

  /// Waits only for runs that belong to the message being submitted now.
  /// A new attachment picked while that bubble uploads belongs to the next
  /// message and must not delay or leak into the current one.
  Future<void> settleCurrent() async {
    final current = _live.toList();
    if (current.isNotEmpty) await Future.wait(current);
  }
}
