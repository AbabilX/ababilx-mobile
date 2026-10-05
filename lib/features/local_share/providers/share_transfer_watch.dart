import 'dart:async';

import '../engine/share_progress.dart';
import 'local_share_net.dart';

/// Tells Android when bytes are moving, so it keeps the app and the Wi-Fi
/// radio alive for exactly that long.
///
/// A transfer is "running" while progress keeps arriving; four quiet seconds
/// end it. Without the foreground service this drives, leaving the app in the
/// middle of a large file killed the transfer within a minute.
class ShareTransferWatch {
  ShareTransferWatch(ShareProgressHub hub) {
    _sub = hub.stream.listen((_) => _beat());
  }

  static const _quiet = Duration(seconds: 4);

  late final StreamSubscription<ShareProgress> _sub;
  Timer? _idle;
  bool _active = false;

  void _beat() {
    if (!_active) {
      _active = true;
      unawaited(LocalShareNet.transferStarted());
    }
    _idle?.cancel();
    _idle = Timer(_quiet, _end);
  }

  void _end() {
    if (!_active) return;
    _active = false;
    unawaited(LocalShareNet.transferEnded());
  }

  Future<void> dispose() async {
    _idle?.cancel();
    _end();
    await _sub.cancel();
  }
}
