import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_list_filters.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import 'chat_recipient_list.dart';
import 'chat_recipient_search_field.dart';
import 'chat_recipient_target.dart';

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
  });

  final String actionLabel;
  final ChatRecipientSubmit onSubmit;
  final String initialCaption;
  final bool showCaption;
  final String? excludedConversationId;

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
    final contacts = ref
        .watch(messageablePeopleProvider)
        .where((person) => person.canMessage)
        .map(ChatRecipientTarget.person)
        .toList();
    final conversations =
        unifiedConversations(dms: chat.dms, channels: chat.channels)
            .where(
              (c) =>
                  c.canMessage &&
                  c.archivedAt == null &&
                  c.id != widget.excludedConversationId,
            )
            .toList();
    final query = _search.text.trim().toLowerCase();
    final recent = conversations
        .take(7)
        .map((c) => ChatRecipientTarget.conversation(c, chat.currentUserId))
        .toList();
    final remainingGroups = conversations
        .skip(7)
        .where((c) => c.isGroupConversation)
        .map((c) => ChatRecipientTarget.conversation(c, chat.currentUserId))
        .toList();
    final shownContacts = _filter(contacts, query);
    final shownRecent = _filter(recent, query);
    final shownGroups = _filter(remainingGroups, query);
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
                recent: shownRecent,
                groups: shownGroups,
                contacts: shownContacts,
                selected: _selected.keys.toSet(),
                enabled: !_sending,
                onToggle: _toggle,
                recentLabel: query.isEmpty
                    ? _tr('chat_recent_chats')
                    : _tr('chat_results'),
                groupsLabel: _tr('chat_groups'),
                contactsLabel: _tr('crm_contacts'),
                emptyLabel: _tr('chat_no_recipients'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selected.isEmpty ? null : _sendBar(),
    );
  }

  List<ChatRecipientTarget> _filter(
    List<ChatRecipientTarget> items,
    String query,
  ) {
    if (query.isEmpty) return items;
    return items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  Widget _sendBar() => SafeArea(
    top: false,
    child: Material(
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
    ),
  );

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.onSubmit(_selected.values.toList(), _caption.text.trim());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toggle(ChatRecipientTarget target) => setState(() {
    if (_selected.remove(target.selectionKey) == null) {
      _selected[target.selectionKey] = target;
    }
  });

  String _tr(String key) => AppTranslations.translate(context, ref, key);
}
