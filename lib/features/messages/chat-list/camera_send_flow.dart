import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../chat-recipient-picker/chat_recipient_picker_screen.dart';
import '../chat-recipient-picker/chat_recipient_target.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import 'camera_capture.dart';
import 'camera_send_targets.dart';

/// The chat list's camera button: shoot, then pick where it goes in the same
/// full-screen picker a forward uses — chats and groups, several at once.
Future<void> captureAndSendChatPhoto(
  BuildContext context,
  WidgetRef ref,
) async {
  final ChatCameraCapture? capture;
  try {
    capture = await captureForChat(ref);
  } catch (_) {
    if (context.mounted) _toast(context, ref, 'chat_camera_send_failed');
    return;
  }
  if (capture == null || capture.isEmpty || !context.mounted) return;
  final shot = capture;
  // The picker watches the people list, so it fills in when this answers.
  unawaited(
    ref.read(chatConnectionsProvider.notifier).refresh().catchError((_) {}),
  );
  // The camera starts inside HomeShell's nested navigator. The picker goes on
  // the root so the shell bar cannot cover its send bar.
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatRecipientPickerScreen(
        title: AppTranslations.translate(context, ref, 'chat_send_to'),
        actionLabel: AppTranslations.translate(context, ref, 'chat_send'),
        onSubmit: (targets, _) => _send(context, ref, shot, targets),
      ),
    ),
  );
}

/// Resolving stays under the picker's spinner (opening a DM is a request, and
/// its failure is the picker's to report). The uploads run behind: the picker
/// closes at once and the outcome is told on the root overlay.
Future<void> _send(
  BuildContext context,
  WidgetRef ref,
  ChatCameraCapture capture,
  List<ChatRecipientTarget> targets,
) async {
  final notifier = ref.read(chatProvider.notifier);
  final ids = await resolveCameraTargets(
    notifier,
    ref.read(chatProvider).dms,
    targets,
  );
  if (ids.isEmpty) throw StateError('no destination');
  if (!context.mounted) return;

  String tr(String key) => AppTranslations.translate(context, ref, key);
  final words = (
    failed: tr('chat_camera_send_failed'),
    partial: tr('chat_camera_sent_partial'),
  );
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final adopter = ref.read(attachmentAdopterProvider);
  showAppToast(context, tr('chat_photo_sending'));
  Navigator.of(context, rootNavigator: true).pop();

  unawaited(
    sendCameraCapture(
      notifier: notifier,
      adopter: adopter,
      capture: capture,
      conversationIds: ids,
    ).then((result) {
      if (result.noneSent) {
        return showAppToastIn(overlay, words.failed, isError: true);
      }
      if (!result.allSent) {
        return showAppToastIn(
          overlay,
          words.partial
              .replaceAll('{sent}', '${result.sent}')
              .replaceAll('{n}', '${result.total}'),
          isError: true,
        );
      }
      // One chat: land in it, where the photo now is. Several: stay put.
      if (ids.length == 1 && context.mounted) {
        context.push('/messages/${ids.first}');
      }
    }),
  );
}

void _toast(BuildContext context, WidgetRef ref, String key) => showAppToast(
  context,
  AppTranslations.translate(context, ref, key),
  isError: true,
);
