import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/video_thumbnail.dart';
import '../../../shared/onboarding/onboarding_page.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../../profile/data/session_repository.dart';
import '../transfer_chats_service.dart';
import '../transfer_receive_session.dart';
import '../wire/transfer_chats_wire.dart';
import 'transfer_chats_copy.dart';
import 'transfer_receive_body.dart';

/// The new phone's side: the code, then the progress, then Continue.
/// Pops `true` once the chats and the message key are on this phone.
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
  bool _startFailed = false;

  @override
  void initState() {
    super.initState();
    // A sleeping screen pauses the app, and the transfer with it.
    unawaited(VideoThumbnails.keepScreenOn(true));
    unawaited(_start());
  }

  Future<void> _start() async {
    final old = _session;
    setState(() {
      _session = null;
      _startFailed = false;
    });
    await old?.dispose();
    try {
      final session = TransferReceiveSession(
        service: ref.read(transferChatsServiceProvider),
        vault: ref.read(messageVaultProvider),
        sessions: ref.read(sessionRepositoryProvider),
        userId: await ref.read(chatProvider.notifier).ensureCurrentUserId(),
      )..keyAdopted = old?.keyAdopted ?? false;
      if (!mounted) return session.dispose();
      setState(() => _session = session);
      await session.start();
    } catch (_) {
      if (mounted) setState(() => _startFailed = true);
    }
  }

  @override
  void dispose() {
    unawaited(VideoThumbnails.keepScreenOn(false));
    unawaited(_session?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => transferText(ref, key);
    final session = _session;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: session == null
              ? _frame(
                  t,
                  _startFailed
                      ? TransferMessage(
                          text: t('receive_error'),
                          onRetry: _start,
                        )
                      : const Center(child: CircularProgressIndicator()),
                )
              : ValueListenableBuilder<String?>(
                  valueListenable: session.payload,
                  builder: (_, payload, _) =>
                      ValueListenableBuilder<TransferStatus>(
                        valueListenable: session.status,
                        builder: (_, status, _) => _frame(
                          t,
                          TransferReceiveBody(
                            payload: payload,
                            status: status,
                            onRetry: _start,
                            onDone: () => Navigator.of(context).pop(true),
                          ),
                          done: status.step == TransferStep.done,
                        ),
                      ),
                ),
        ),
      ),
    );
  }

  /// Cancel and back. A key that already arrived counts as done: the
  /// restore screen behind would otherwise offer to start fresh over it.
  void _leave() => Navigator.of(context).pop(_session?.keyAdopted ?? false);

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
