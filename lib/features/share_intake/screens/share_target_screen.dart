import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/new-message/new_message_search.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/shared_payload.dart';
import '../providers/share_intake_provider.dart';
import '../services/share_sender.dart';
import '../share-target/share_compose_header.dart';
import '../share-target/share_result_report.dart';
import '../share-target/share_target_list.dart';

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
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final TextEditingController _caption;
  final _selected = <String>{};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final payload = ref.read(shareIntakeProvider);
    // A text-only share *is* the message; a file share often arrives with a
    // caption from the sending app. Either way it belongs in the field, where
    // the user can still edit it.
    _caption = TextEditingController(text: payload?.text ?? '');
    // Opened straight from another app, so nothing may have loaded the chat
    // list yet.
    unawaited(ref.read(chatProvider.notifier).ensureReady());
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _cancel() {
    ref.read(shareIntakeProvider.notifier).consume();
    context.go('/messages');
  }

  Future<void> _send(SharedPayload payload) async {
    final body = _caption.text.trim();
    if (_selected.isEmpty || _sending) return;
    if (!payload.hasFiles && body.isEmpty) return;

    setState(() => _sending = true);
    final targets = _selected.toList();
    ShareSendResult result;
    try {
      result = await sendSharedPayload(
        chat: ref.read(chatProvider.notifier),
        channel: ref.read(shareIntakeChannelProvider),
        payload: payload,
        body: body,
        conversationIds: targets,
      );
    } catch (_) {
      result = ShareSendResult(sent: 0, failed: targets);
    }
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.noneSent) {
      ShareResultReport.failure(context);
      return;
    }
    ref.read(shareIntakeProvider.notifier).consume();
    // One recipient: drop the user into that thread, which is where they
    // expect to end up. Several: back to the list.
    if (targets.length == 1 && result.allSent && result.skippedFiles == 0) {
      context.go('/messages/${targets.first}');
      return;
    }
    context.go('/messages');
    ShareResultReport.partial(context, result, targets.length);
  }

  @override
  Widget build(BuildContext context) {
    final payload = ref.watch(shareIntakeProvider);
    if (payload == null) {
      // Consumed already (a second frame after send, or a stale route).
      return const Scaffold(body: SizedBox.shrink());
    }

    final chat = ref.watch(chatProvider);
    final query = _search.text.trim().toLowerCase();
    final targets =
        [...chat.dms, ...chat.channels]
            .where((c) => c.canMessage && c.archivedAt == null)
            .where(
              (c) =>
                  query.isEmpty ||
                  c
                      .displayTitle(chat.currentUserId)
                      .toLowerCase()
                      .contains(query),
            )
            .toList();

    final canSend =
        !_sending &&
        _selected.isNotEmpty &&
        (payload.hasFiles || _caption.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _sending ? null : _cancel,
        ),
        title: const Text('Share with'),
      ),
      body: Column(
        children: [
          ShareComposeHeader(
            payload: payload,
            caption: _caption,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
          ),
          NewMessageSearch(
            controller: _search,
            focusNode: _searchFocus,
            hintText: 'Search conversations',
            onChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: ShareTargetList(
              conversations: targets,
              currentUserId: chat.currentUserId,
              selected: _selected,
              enabled: !_sending,
              onToggle: (id) => setState(() {
                if (!_selected.remove(id)) _selected.add(id);
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: canSend ? () => _send(payload) : null,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _selected.isEmpty
                        ? 'Send'
                        : 'Send to ${_selected.length}',
                  ),
          ),
        ),
      ),
    );
  }
}
