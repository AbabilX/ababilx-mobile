import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/video_thumbnail.dart';
import '../../../shared/onboarding/onboarding_page.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../local_share/widgets/qr_scan_sheet.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../../profile/data/session_repository.dart';
import '../transfer_chats_service.dart';
import '../transfer_pull_session.dart';
import '../transfer_receive_session.dart';
import '../wire/transfer_chats_payload.dart';
import '../wire/transfer_chats_wire.dart';
import 'transfer_chats_copy.dart';
import 'transfer_receive_body.dart';

/// The new phone's side: its own code for another phone to scan, or — a
/// computer has no camera — the computer's code scanned from here. Pops
/// `true` once the message key is on this phone.
class TransferReceiveScreen extends ConsumerStatefulWidget {
  const TransferReceiveScreen({super.key});

  static Future<bool> open(BuildContext context) async =>
      await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(builder: (_) => const TransferReceiveScreen()),
      ) ??
      false;

  @override
  ConsumerState<TransferReceiveScreen> createState() => _State();
}

class _State extends ConsumerState<TransferReceiveScreen> {
  TransferReceiveSession? _session;
  TransferPullSession? _pull;
  bool _startFailed = false;
  bool _earlierKey = false;

  /// A key that arrived on any attempt counts: leaving must never offer
  /// "start fresh" over it.
  bool get _keyAdopted =>
      _earlierKey ||
      (_session?.keyAdopted ?? false) ||
      (_pull?.keyAdopted ?? false);

  @override
  void initState() {
    super.initState();
    // A sleeping screen pauses the app, and the transfer with it.
    unawaited(VideoThumbnails.keepScreenOn(true));
    unawaited(_start());
  }

  /// Takes the current session off screen, then disposes it after the next
  /// frame: its notifiers must outlive the builders still listening to them.
  Future<void> _drop({bool now = false}) async {
    _earlierKey = _keyAdopted;
    final session = _session, pull = _pull;
    if (session == null && pull == null) return;
    _session = null;
    _pull = null;
    Future<void> release() async {
      await session?.dispose();
      await pull?.dispose();
    }

    if (now || !mounted) return release();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(release()));
  }

  Future<String> _userId() =>
      ref.read(chatProvider.notifier).ensureCurrentUserId();

  Future<void> _start() async {
    await _drop();
    if (!mounted) return;
    setState(() => _startFailed = false);
    try {
      final session = TransferReceiveSession(
        service: ref.read(transferChatsServiceProvider),
        vault: ref.read(messageVaultProvider),
        sessions: ref.read(sessionRepositoryProvider),
        userId: await _userId(),
      );
      if (!mounted) return session.dispose();
      setState(() => _session = session);
      await session.start();
    } catch (_) {
      if (mounted) setState(() => _startFailed = true);
    }
  }

  /// A computer drew the code; this phone takes its chats.
  Future<void> _fromComputer() async {
    final raw = await QrScanSheet.show(context);
    if (raw == null || !mounted) return;
    final code = parseTransferChatsPayload(raw);
    if (code == null || !code.pull) {
      showAppToast(
        context,
        transferText(ref, 'error_not_computer'),
        isError: true,
      );
      return;
    }
    await _drop();
    final pull = TransferPullSession(
      service: ref.read(transferChatsServiceProvider),
      vault: ref.read(messageVaultProvider),
      sessions: ref.read(sessionRepositoryProvider),
      userId: await _userId(),
      code: code,
    );
    if (!mounted) return pull.dispose();
    setState(() => _pull = pull);
    unawaited(pull.run());
  }

  @override
  void dispose() {
    unawaited(VideoThumbnails.keepScreenOn(false));
    unawaited(_drop(now: true));
    super.dispose();
  }

  void _leave() => Navigator.of(context).pop(_keyAdopted);

  @override
  Widget build(BuildContext context) {
    String t(String key) => transferText(ref, key);
    final session = _session, pull = _pull;
    Widget follow(ValueNotifier<TransferStatus> status, String? payload) =>
        ValueListenableBuilder<TransferStatus>(
          valueListenable: status,
          builder: (_, s, _) => _frame(
            t,
            TransferReceiveBody(
              payload: payload,
              status: s,
              onRetry: _start,
              onDone: () => Navigator.of(context).pop(true),
              onScanComputer: _fromComputer,
            ),
            done: s.step == TransferStep.done,
          ),
        );
    final Widget body;
    if (pull != null) {
      body = follow(pull.status, 'pull');
    } else if (session != null) {
      body = ValueListenableBuilder<String?>(
        valueListenable: session.payload,
        builder: (_, payload, _) => follow(session.status, payload),
      );
    } else {
      body = _frame(
        t,
        _startFailed
            ? TransferMessage(text: t('receive_error'), onRetry: _start)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(body: SafeArea(child: body)),
    );
  }

  Widget _frame(String Function(String) t, Widget body, {bool done = false}) =>
      OnboardingPage(
        title: t(done ? 'done_title' : 'receive_title'),
        gap: 24,
        bottom: done
            ? null
            : Center(
                child: TextButton(onPressed: _leave, child: Text(t('cancel'))),
              ),
        children: [body],
      );
}
