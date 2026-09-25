import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_translations.dart';
import '../../core/router/app_router.dart';
import '../calls/group/providers/group_call_provider.dart';
import '../calls/providers/voice_call_provider.dart';
import 'app_update_info.dart';
import 'app_update_provider.dart';
import 'app_update_required_screen.dart';
import 'app_update_sheet.dart';
import 'app_update_snooze.dart';

/// Puts the update check's answer on screen, above every route.
///
/// Required: [AppUpdateRequiredScreen] covers the app. Optional: a bottom
/// sheet, once per build per launch, unless snoozed. Neither appears during
/// a call — a live call is never covered — and both wait for it to end.
///
/// The subtree shape never changes: [child] is go_router's navigator, keyed
/// by a GlobalKey, so it always sits in slot 0 and slot 1 is always filled
/// (see ActiveCallBanner for the crash that rule prevents).
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  /// Delay before offering an optional update, so it never lands on top of
  /// the first frame or the launch permission prompts.
  static const _promptDelay = Duration(seconds: 3);

  int _promptedBuild = 0;

  bool get _inCall =>
      ref.read(voiceCallProvider).active || ref.read(groupCallProvider).active;

  Future<void> _considerPrompt() async {
    final info = ref.read(appUpdateProvider);
    if (info == null ||
        !info.updateAvailable ||
        info.updateRequired ||
        info.latestBuild == _promptedBuild ||
        _inCall) {
      return;
    }
    _promptedBuild = info.latestBuild;
    if (await AppUpdateSnooze.isSnoozed(info.latestBuild)) return;
    await Future<void>.delayed(_promptDelay);
    final context = rootNavigatorKey.currentContext;
    if (!mounted || context == null || !context.mounted || _inCall) {
      _promptedBuild = 0; // try again when the call ends
      return;
    }
    await showAppUpdateSheet(
      context,
      info,
      lang: ref.read(appLanguageProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppUpdateInfo?>(
      appUpdateProvider,
      (_, _) => unawaited(_considerPrompt()),
    );
    ref.listen<bool>(
      voiceCallProvider.select((s) => s.active),
      (_, active) => active ? null : unawaited(_considerPrompt()),
    );
    ref.listen<bool>(
      groupCallProvider.select((s) => s.active),
      (_, active) => active ? null : unawaited(_considerPrompt()),
    );

    final info = ref.watch(appUpdateProvider);
    final inCall =
        ref.watch(voiceCallProvider.select((s) => s.active)) ||
        ref.watch(groupCallProvider.select((s) => s.active));
    final blocked = info != null && info.updateRequired && !inCall;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        blocked ? AppUpdateRequiredScreen(info: info) : const SizedBox.shrink(),
      ],
    );
  }
}
