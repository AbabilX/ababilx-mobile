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
  final Queue<Completer<bool>> _user = Queue();
  final Queue<Completer<bool>> _auto = Queue();
  int _active = 0;

  int get active => _active;

  /// False means the waiter was cancelled without taking a slot.
  Future<bool> acquire({required bool userInitiated, Future<void>? cancelled}) {
    if (_active < maxConcurrent) {
      _active++;
      return Future.value(true);
    }
    final completer = Completer<bool>();
    final waiters = userInitiated ? _user : _auto;
    waiters.add(completer);
    cancelled?.then((_) {
      if (waiters.remove(completer)) completer.complete(false);
    });
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
    next.complete(true);
  }

  /// Frees every waiter so a disposing owner cannot leave futures hanging.
  void drain() {
    for (final completer in [..._user, ..._auto]) {
      if (!completer.isCompleted) completer.complete(false);
    }
    _user.clear();
    _auto.clear();
    _active = 0;
  }
}
