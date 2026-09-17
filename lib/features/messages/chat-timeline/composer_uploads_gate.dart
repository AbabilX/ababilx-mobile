import 'dart:async';

import 'package:dio/dio.dart';

class _TrackedUpload {
  _TrackedUpload(this.future, this.token);
  final Future<void> future;
  final CancelToken token;
}

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
  final _live = <_TrackedUpload>{};

  bool get busy => _live.isNotEmpty;

  /// Follows one attach run. Failures are the caller's to report; they must
  /// not surface here as an unhandled error on a future nobody awaited.
  ///
  /// Returns the [CancelToken] for that run so a later Cancel on the uploading
  /// bubble can abort PUTs still in flight.
  CancelToken track(Future<void> run, {CancelToken? cancelToken}) {
    final token = cancelToken ?? CancelToken();
    final quiet = run.catchError((Object _) {});
    final entry = _TrackedUpload(quiet, token);
    _live.add(entry);
    quiet.whenComplete(() => _live.remove(entry));
    return token;
  }

  /// Aborts every live PUT. Settling afterwards resolves quickly with failures.
  void cancelAll() {
    for (final entry in _live.toList()) {
      if (!entry.token.isCancelled) {
        entry.token.cancel('cancelled by user');
      }
    }
  }

  Future<void> settle() async {
    while (_live.isNotEmpty) {
      await Future.wait(_live.map((e) => e.future));
    }
  }

  /// Waits only for runs that belong to the message being submitted now.
  /// A new attachment picked while that bubble uploads belongs to the next
  /// message and must not delay or leak into the current one.
  Future<void> settleCurrent() async {
    final current = _live.map((e) => e.future).toList();
    if (current.isNotEmpty) await Future.wait(current);
  }
}
