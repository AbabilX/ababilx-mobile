import 'package:flutter/widgets.dart';

import '../data/models/chat_models.dart';

/// The fade on a sending bubble's clock, run only while that message is
/// actually sending or uploading.
///
/// It used to `repeat()` from every row's `initState`, forever. Only a pending
/// bubble ever draws it, but a running controller keeps its ticker asking for
/// a frame on every vsync — so an open chat never went idle, and every
/// message on screen paid for a clock nobody could see.
///
/// Built in `initState`, never as a `late final` initialiser: a row that is
/// never pending would otherwise create its ticker from `dispose()`, on a
/// deactivated element, and throw (the same trap `MessageSwipeReply` notes).
mixin MessageRowPulse<T extends StatefulWidget>
    on SingleTickerProviderStateMixin<T> {
  /// The message whose send state drives the pulse.
  ChatMessage get pulsedMessage;

  late AnimationController _pulseCtrl;
  late Animation<double> pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    pulse = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _syncPulse() {
    final status = pulsedMessage.sendStatus;
    final pending =
        status == MessageSendStatus.sending ||
        status == MessageSendStatus.uploading;
    if (pending && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!pending && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }
}
