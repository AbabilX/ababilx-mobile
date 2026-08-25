import 'dart:async';
import 'dart:collection';

/// Two-tier concurrency gate.
///
/// A tapped download must not sit behind a queue of automatic ones the user
/// never asked for, so waiters are kept in two lists and the user list is
/// always drained first.
class AttachmentSemaphore {
  AttachmentSemaphore(this.maxConcurrent);

  final int maxConcurrent;
  final Queue<Completer<void>> _user = Queue();
  final Queue<Completer<void>> _auto = Queue();
  int _active = 0;

  int get active => _active;

  Future<void> acquire({required bool userInitiated}) {
    if (_active < maxConcurrent) {
      _active++;
      return Future.value();
    }
    final completer = Completer<void>();
    (userInitiated ? _user : _auto).add(completer);
    return completer.future;
  }

  void release() {
    final next = _user.isNotEmpty
        ? _user.removeFirst()
        : (_auto.isNotEmpty ? _auto.removeFirst() : null);
    if (next == null) {
      if (_active > 0) _active--;
      return;
    }
    next.complete();
  }

  /// Frees every waiter so a disposing owner cannot leave futures hanging.
  void drain() {
    for (final completer in [..._user, ..._auto]) {
      if (!completer.isCompleted) completer.complete();
    }
    _user.clear();
    _auto.clear();
    _active = 0;
  }
}
