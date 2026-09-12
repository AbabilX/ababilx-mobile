import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/media_quality.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../messages/chat-recipient-picker/chat_recipient_picker_screen.dart';
import '../../messages/chat-recipient-picker/chat_recipient_target.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/shared_payload.dart';
import '../providers/share_intake_provider.dart';
import '../services/share_review.dart';
import '../services/share_sender.dart';
import '../share-target/share_result_report.dart';

/// Where an incoming share lands: pick one or more conversations, add a
/// caption, send.
///
/// Signal's flow, and for the same reason — the system share sheet has already
/// taken the user out of the other app, so making them then find the chat by
/// hand would waste the trip.
class ShareTargetScreen extends ConsumerStatefulWidget {
  const ShareTargetScreen({super.key});

  @override
  ConsumerState<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends ConsumerState<ShareTargetScreen> {
  /// Null until the review screen has had its turn. The recipient picker waits
  /// for it, so a shared photo is not offered for sending before the user has
  /// had the chance to crop it.
  SharedPayload? _reviewed;
  bool _reviewing = true;

  @override
  void initState() {
    super.initState();
    // Opened straight from another app, so nothing may have loaded the chat
    // list yet.
    unawaited(ref.read(chatProvider.notifier).ensureReady());
    unawaited(_review());
  }

  Future<void> _review() async {
    final payload = ref.read(shareIntakeProvider);
    if (payload == null) {
      if (mounted) setState(() => _reviewing = false);
      return;
    }
    final result = await reviewSharedPayload(
      payload,
      ref.read(mediaQualityProvider),
    );
    await ref.read(mediaQualityProvider.notifier).set(result.quality);
    if (!mounted) return;
    if (result.cancelled) {
      // Backing out of the review screen abandons the share; sending the
      // originals anyway would be the opposite of what Cancel means.
      ref.read(shareIntakeProvider.notifier).consume();
      context.go('/messages');
      return;
    }
    setState(() {
      _reviewed = result.payload;
      _reviewing = false;
    });
  }

  Future<void> _send(
    SharedPayload payload,
    List<ChatRecipientTarget> targets,
    String body,
  ) async {
    if (!payload.hasFiles && body.isEmpty) {
      ShareResultReport.nothingToSend(context);
      return;
    }
    // Resolving is inside the reporting, not before it. A picked person with
    // no chat yet is opened with `startDm` here, and that is a network call:
    // its throw used to escape `_send` entirely, into the picker's own
    // `catch (_)`, so Send spun once and did nothing at all.
    List<String> conversationIds;
    try {
      conversationIds = await _resolveConversationIds(targets);
    } catch (error) {
      if (mounted) ShareResultReport.error(context, error);
      return;
    }
    if (!mounted) return;
    if (conversationIds.isEmpty) {
      ShareResultReport.noRecipients(context);
      return;
    }
    ShareSendResult result;
    try {
      result = await sendSharedPayload(
        chat: ref.read(chatProvider.notifier),
        channel: ref.read(shareIntakeChannelProvider),
        payload: payload,
        body: body,
        conversationIds: conversationIds,
        adopter: ref.read(attachmentAdopterProvider),
      );
    } catch (_) {
      result = ShareSendResult(sent: 0, failed: conversationIds);
    }
    if (!mounted) return;
    if (result.noneSent) {
      ShareResultReport.failure(context);
      return;
    }
    ref.read(shareIntakeProvider.notifier).consume();
    // One recipient: drop the user into that thread, which is where they
    // expect to end up. Several: back to the list.
    if (conversationIds.length == 1 &&
        result.allSent &&
        result.skippedFiles == 0) {
      context.go('/messages/${conversationIds.first}');
      return;
    }
    context.go('/messages');
    ShareResultReport.partial(context, result, conversationIds.length);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(shareIntakeProvider);
    if (pending == null) {
      // Consumed already (a second frame after send, or a stale route).
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_reviewing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    final payload = _reviewed ?? pending;

    return ChatRecipientPickerScreen(
      actionLabel: AppTranslations.translate(context, ref, 'chat_send'),
      initialCaption: payload.text,
      showCaption: true,
      onSubmit: (targets, body) => _send(payload, targets, body),
    );
  }

  Future<List<String>> _resolveConversationIds(
    List<ChatRecipientTarget> targets,
  ) async {
    final chat = ref.read(chatProvider);
    final ids = <String>{};
    for (final target in targets) {
      if (target.kind == ChatRecipientKind.conversation) {
        ids.add(target.id);
        continue;
      }
      final existing = chat.dms.where((dm) => dm.peerUserId == target.id);
      ids.add(
        existing.isNotEmpty
            ? existing.first.id
            : (await ref.read(chatProvider.notifier).startDm(target.id)).id,
      );
    }
    return ids.toList();
  }
}
