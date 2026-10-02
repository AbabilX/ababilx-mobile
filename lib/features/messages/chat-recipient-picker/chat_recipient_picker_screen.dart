import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import 'chat_recipient_eligible.dart';
import 'chat_recipient_list.dart';
import 'chat_recipient_sections.dart';
import 'chat_recipient_search_field.dart';
import 'chat_recipient_target.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';

typedef ChatRecipientSubmit =
    Future<void> Function(List<ChatRecipientTarget> recipients, String caption);

/// Full-screen, Signal-inspired destination picker for shares and forwards.
class ChatRecipientPickerScreen extends ConsumerStatefulWidget {
  const ChatRecipientPickerScreen({
    super.key,
    required this.actionLabel,
    required this.onSubmit,
    this.initialCaption = '',
    this.showCaption = false,
    this.excludedConversationId,
    this.preselectedConversationId = '',
  });

  final String actionLabel;
  final ChatRecipientSubmit onSubmit;
  final String initialCaption;
  final bool showCaption;
  final String? excludedConversationId;

  /// Ticked once it appears in the list (a Direct Share target).
  final String preselectedConversationId;

  @override
  ConsumerState<ChatRecipientPickerScreen> createState() =>
      _ChatRecipientPickerScreenState();
}

class _ChatRecipientPickerScreenState
    extends ConsumerState<ChatRecipientPickerScreen> {
  final _search = TextEditingController();
  late final TextEditingController _caption;
  final _selected = <String, ChatRecipientTarget>{};
  bool _sending = false;
  bool _preselected = false;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _search.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final people = ref
        .watch(messageablePeopleProvider)
        .where((person) => person.canMessage)
        .toList();
    final locks = ref.watch(chatLocksProvider);
    final conversations = shareableConversations(
      dms: chat.dms,
      channels: chat.channels,
      locks: locks,
      excludedConversationId: widget.excludedConversationId,
    );
    _preselect(conversations, chat.currentUserId);
    final query = _search.text.trim();
    final sections = buildChatRecipientSections(
      conversations: conversations,
      people: people,
      currentUserId: chat.currentUserId,
      query: query,
    );
    // Send bar in the body, not `bottomNavigationBar`: only the body is inset
    // by `viewInsets`, so only there does the caption ride above the keyboard.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ChatRecipientSearchField(
              controller: _search,
              hintText: _tr('chat_recipient_search'),
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: ChatRecipientList(
                recent: sections.recent,
                groups: sections.groups,
                contacts: sections.contacts,
                selected: _selected.keys.toSet(),
                enabled: !_sending,
                onToggle: _toggle,
                recentLabel: query.isEmpty
                    ? _tr('chat_recent_chats')
                    : _tr('chat_results'),
                groupsLabel: _tr('chat_groups'),
                contactsLabel: _tr('chat_contacts'),
                emptyLabel: _tr('chat_no_recipients'),
              ),
            ),
            if (_selected.isNotEmpty) _sendBar(),
          ],
        ),
      ),
    );
  }

  // The enclosing SafeArea already holds the gesture inset.
  Widget _sendBar() => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showCaption)
            TextField(
              controller: _caption,
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: InputDecoration(hintText: _tr('chat_add_message')),
            ),
          if (widget.showCaption) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('${widget.actionLabel} (${_selected.length})'),
            ),
          ),
        ],
      ),
    ),
  );

  /// The spinner must come back for ANY outcome. Reporting failure is the
  /// caller's job, but this catch is the last thing between an unforeseen
  /// throw (the share flow's `startDm` once) and a Send that says nothing.
  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.onSubmit(_selected.values.toList(), _caption.text.trim());
    } catch (_) {
      if (mounted) {
        showAppToast(context, _tr('chat_send_failed'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Applied once, in build: the chat list may still be loading on open.
  void _preselect(List<ChatConversation> list, String userId) {
    final id = widget.preselectedConversationId;
    if (_preselected || id.isEmpty) return;
    final match = list.where((c) => c.id == id);
    if (match.isEmpty) return;
    _preselected = true;
    final target = ChatRecipientTarget.conversation(match.first, userId);
    _selected[target.selectionKey] = target;
  }

  void _toggle(ChatRecipientTarget target) => setState(() {
    if (_selected.remove(target.selectionKey) == null) {
      _selected[target.selectionKey] = target;
    }
  });

  String _tr(String key) => AppTranslations.translate(context, ref, key);
}
