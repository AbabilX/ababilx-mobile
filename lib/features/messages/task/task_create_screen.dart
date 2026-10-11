import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-timeline/composer_attach.dart';
import '../data/models/chat_models.dart';
import '../message_length_limit.dart';
import '../providers/chat_provider.dart';
import 'task_attach.dart';
import 'task_card_data.dart';
import 'task_create_fields.dart';
import '../../../shared/widgets/capsule_form_header.dart';
import 'task_discard_sheet.dart';
import '../send-later/send_later_flow.dart';
import 'task_send.dart';
import 'task_strings.dart';

/// Opens the new-task page for the DM [conversationId].
Future<void> openTaskCreate(
  BuildContext context, {
  required String conversationId,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => TaskCreateScreen(conversationId: conversationId),
  ),
);

/// A task for the other person: title, description, priority and files.
class TaskCreateScreen extends ConsumerStatefulWidget {
  const TaskCreateScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<TaskCreateScreen> createState() => _TaskCreateState();
}

class _TaskCreateState extends ConsumerState<TaskCreateScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _files = <ChatAttachmentInput>[];
  final _cancel = CancelToken(); // stops transfers when the page is left
  TaskPriority _priority = TaskPriority.medium;
  int _uploads = 0;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  TaskStrings get _s => TaskStrings.of(ref.read(appLanguageProvider));
  bool get _busy => _sending || _uploads > 0;

  Future<void> _attach(ComposerAttachKind kind) async {
    if (_sending) return;
    setState(() => _uploads += 1);
    await attachTaskFiles(
      context,
      ref,
      conversationId: widget.conversationId,
      kind: kind,
      failedText: _s.uploadFailed,
      cancelToken: _cancel,
      onAdded: (file) {
        if (mounted) setState(() => _files.add(file));
      },
      onFailed: (url) {
        if (!mounted) return;
        setState(() => _files.removeWhere((f) => f.fileUrl == url));
      },
    );
    if (mounted) setState(() => _uploads -= 1);
  }

  void _remove(ChatAttachmentInput file) {
    setState(() => _files.remove(file));
    ref
        .read(chatProvider.notifier)
        .discardUpload(widget.conversationId, file.fileUrl);
  }

  /// Send held down: pick a time, then the same send with it.
  Future<void> _sendLater() async {
    if (_busy) return;
    final at = await pickSendLaterTime(context, ref, widget.conversationId);
    if (at != null && mounted) await _send(at: at);
  }

  Future<void> _send({DateTime? at}) async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      showAppToast(context, _s.needTitle, isError: true);
      return;
    }
    if (isMessageTooLong(taskBodyText(title, _description.text))) {
      showAppToast(
        context,
        messageTooLongText(ref.read(appLanguageProvider)),
        isError: true,
      );
      return;
    }
    setState(() => _sending = true);
    final sent = await sendTask(
      context,
      ref,
      conversationId: widget.conversationId,
      title: title,
      description: _description.text,
      priority: _priority,
      attachments: List.of(_files),
      sendAt: at,
    );
    if (!mounted) return;
    if (sent) return Navigator.of(context).pop();
    setState(() => _sending = false);
  }

  Future<void> _back() async {
    if (_sending) return;
    final navigator = Navigator.of(context);
    final empty =
        _title.text.trim().isEmpty &&
        _description.text.trim().isEmpty &&
        _files.isEmpty;
    if (!empty && !await confirmTaskDiscard(context, _s)) return;
    _cancel.cancel();
    final notifier = ref.read(chatProvider.notifier);
    for (final file in _files) {
      notifier.discardUpload(widget.conversationId, file.fileUrl);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = TaskStrings.of(ref.watch(appLanguageProvider));
    final label = Theme.of(context).textTheme.labelLarge;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.viewPaddingOf(context).top + 76,
                  16,
                  MediaQuery.viewPaddingOf(context).bottom + 24,
                ),
                children: [
                  TaskTextFields(
                    title: _title,
                    description: _description,
                    strings: s,
                    enabled: !_sending,
                  ),
                  const SizedBox(height: 16),
                  Text(s.priority, style: label),
                  const SizedBox(height: 6),
                  TaskPriorityPicker(
                    value: _priority,
                    strings: s,
                    onChanged: _sending
                        ? null
                        : (p) => setState(() => _priority = p),
                  ),
                  const SizedBox(height: 16),
                  TaskAttachButtons(
                    strings: s,
                    onAttach: _sending ? null : _attach,
                  ),
                  if (_files.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TaskFileChips(
                      files: _files,
                      onRemove: _busy ? null : _remove,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CapsuleFormHeader(
                title: s.createTitle,
                sendLabel: _uploads > 0 ? s.uploading : s.send,
                onBack: _back,
                onSend: _busy ? null : _send,
                onSendLater: _sendLater,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
