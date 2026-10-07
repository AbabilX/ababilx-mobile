import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/capsule_form_header.dart';
import '../../../shared/widgets/app_toast.dart';
import '../group-member-permissions/group_media_guard.dart';
import '../message_length_limit.dart';
import 'snippet_discard_sheet.dart';
import 'snippet_fields.dart';
import 'snippet_format.dart';
import 'snippet_send.dart';
import 'snippet_strings.dart';

/// Opens the snippet page for [conversationId]. [parentId] is the thread root
/// when it was opened from a thread.
///
/// [initialContent] fills the content box — a draft too long to send as a
/// message. True when the snippet went out.
Future<bool> openSnippetCreate(
  BuildContext context, {
  required String conversationId,
  String? parentId,
  String initialContent = '',
}) async {
  final sent = await Navigator.of(context).push(
    MaterialPageRoute<bool>(
      builder: (_) => SnippetCreateScreen(
        conversationId: conversationId,
        parentId: parentId,
        initialContent: initialContent,
      ),
    ),
  );
  return sent ?? false;
}

/// Long text sent as a `.md` or `.txt` file: title, type, content and an
/// optional message, then Send.
class SnippetCreateScreen extends ConsumerStatefulWidget {
  const SnippetCreateScreen({
    super.key,
    required this.conversationId,
    this.parentId,
    this.initialContent = '',
  });

  final String conversationId;
  final String? parentId;
  final String initialContent;

  @override
  ConsumerState<SnippetCreateScreen> createState() => _SnippetCreateState();
}

class _SnippetCreateState extends ConsumerState<SnippetCreateScreen> {
  final _title = TextEditingController();
  late final _content = TextEditingController(text: widget.initialContent);
  final _message = TextEditingController();
  SnippetKind _kind = SnippetKind.markdown;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _message.dispose();
    super.dispose();
  }

  SnippetStrings get _s => SnippetStrings.of(ref.read(appLanguageProvider));

  Future<void> _send() async {
    if (_sending) return;
    final content = _content.text;
    final language = ref.read(appLanguageProvider);
    if (content.trim().isEmpty) {
      showAppToast(context, _s.empty, isError: true);
      return;
    }
    if (isSnippetTooLarge(content)) {
      showAppToast(context, _s.tooLarge, isError: true);
      return;
    }
    if (isMessageTooLong(_message.text.trim())) {
      showAppToast(context, messageTooLongText(language), isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await sendSnippet(
        ref,
        conversationId: widget.conversationId,
        parentId: widget.parentId,
        title: _title.text,
        kind: _kind,
        content: content,
        message: _message.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on GroupMediaRestrictedException catch (error) {
      if (!mounted) return;
      final copy = groupMediaRestrictedCopy(error.kind);
      showAppToast(
        context,
        language == 'bn' ? copy.bn : copy.en,
        isError: true,
      );
      setState(() => _sending = false);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, _s.failed, isError: true);
      setState(() => _sending = false);
    }
  }

  Future<void> _back() async {
    if (_sending) return;
    final navigator = Navigator.of(context);
    if (_content.text.trim().isEmpty ||
        await confirmSnippetDiscard(context, _s)) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SnippetStrings.of(ref.watch(appLanguageProvider));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.viewPaddingOf(context).top + 76,
                  16,
                  MediaQuery.viewPaddingOf(context).bottom + 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SnippetTitleField(
                      controller: _title,
                      label: s.titleLabel,
                      hint: snippetFileName('', _kind),
                      enabled: !_sending,
                    ),
                    const SizedBox(height: 12),
                    SnippetKindPicker(
                      kind: _kind,
                      strings: s,
                      onChanged: _sending
                          ? null
                          : (kind) => setState(() => _kind = kind),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SnippetContentField(
                        controller: _content,
                        hint: s.contentHint,
                        enabled: !_sending,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SnippetMessageField(
                      controller: _message,
                      hint: s.messageHint,
                      enabled: !_sending,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CapsuleFormHeader(
                title: s.createTitle,
                sendLabel: _sending ? s.sending : s.send,
                onBack: _back,
                onSend: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
