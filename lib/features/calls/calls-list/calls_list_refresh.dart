import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/swipe_tab_active.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/call_log_provider.dart';
import '../providers/voice_call_provider.dart';

/// When Talks asks the server for its history. The list itself comes from the
/// phone; a request goes out only when it may have moved
/// ([CallLogNotifier.refreshIfStale]):
///
///   visit        -> once per launch, then only when stale or >5 min old
///   hidden build -> nothing (the pager builds Talks while Chats is showing)
///   call ends    -> stale; refreshed 2 s later if Talks is on screen
///   app resumes  -> stale (a missed call exists only on the server)
mixin CallsListRefresh<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, SwipeTabVisits<T> {
  late final _lifecycle = AppLifecycleListener(onResume: _onResume);

  void startCallLogRefresh() => _lifecycle;

  void stopCallLogRefresh() => _lifecycle.dispose();

  /// After the frame: [tabActive] is settled by then, and a provider write
  /// must not happen during build.
  void refreshCallLogOnVisit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !tabActive) return;
      ref.read(callLogProvider.notifier).refreshIfStale();
    });
  }

  /// Call from build: a DM or group call going from live to over.
  void watchCallsEnding() {
    ref.listen(voiceCallProvider.select((s) => s.active), (was, now) {
      if (was == true && !now) _onCallEnded();
    });
    ref.listen(groupCallProvider.select((s) => s.active), (was, now) {
      if (was == true && !now) _onCallEnded();
    });
  }

  void _onResume() {
    ref.read(callLogProvider.notifier).markStale();
    refreshCallLogOnVisit();
  }

  /// The server writes the row as the call closes; the wait lets it land.
  void _onCallEnded() {
    final log = ref.read(callLogProvider.notifier)..markStale();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && tabActive) log.refreshIfStale();
    });
  }
}
