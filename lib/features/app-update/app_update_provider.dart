import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_update_check.dart';
import 'app_update_info.dart';

/// The latest answer from the update check, null until one arrives.
///
/// Checked once per launch, and again on returning to the app when the last
/// answer is older than [recheckAfter] — most people never cold-start a
/// messenger, so a launch-only check would miss a required update for weeks.
/// A failed check keeps the previous answer and retries on the next resume.
class AppUpdateNotifier extends Notifier<AppUpdateInfo?> {
  static const recheckAfter = Duration(hours: 6);

  DateTime? _checkedAt;
  bool _checking = false;

  @override
  AppUpdateInfo? build() {
    final life = AppLifecycleListener(onResume: () => unawaited(check()));
    ref.onDispose(life.dispose);
    Future.microtask(() => check(force: true));
    return null;
  }

  Future<void> check({bool force = false}) async {
    if (_checking) return;
    final last = _checkedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < recheckAfter) {
      return;
    }
    _checking = true;
    try {
      final info = await fetchAppUpdate();
      if (info == null) return;
      _checkedAt = DateTime.now();
      state = info;
    } finally {
      _checking = false;
    }
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateInfo?>(
  AppUpdateNotifier.new,
);
