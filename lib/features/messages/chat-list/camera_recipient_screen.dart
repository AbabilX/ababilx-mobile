import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_connection.dart';
import '../new-message/new_message_search.dart';

class CameraRecipientScreen extends ConsumerStatefulWidget {
  const CameraRecipientScreen({
    super.key,
    required this.photoBytes,
    required this.people,
  });

  final Uint8List photoBytes;
  final List<ChatUserSummary> people;

  @override
  ConsumerState<CameraRecipientScreen> createState() =>
      _CameraRecipientScreenState();
}

class _CameraRecipientScreenState extends ConsumerState<CameraRecipientScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  ChatUserSummary? _selected;

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final people = widget.people.where((user) {
      return query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(_tr('chat_send_to'))),
      body: Column(
        children: [
          NewMessageSearch(
            controller: _search,
            focusNode: _focus,
            hintText: _tr('chat_search_recipients'),
            onChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: people.isEmpty
                ? Center(child: Text(_tr('chat_no_people')))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: people.length,
                    itemBuilder: (_, index) => _personRow(people[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selected == null ? null : _sendBar(_selected!),
    );
  }

  Widget _personRow(ChatUserSummary user) {
    final selected = _selected?.userId == user.userId;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        setState(() => _selected = user);
        _focus.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Row(
          children: [
            AppAvatar(size: 48, url: user.avatarUrl, name: user.name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (user.username.isNotEmpty)
                    Text(
                      '@${user.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? colors.primary : colors.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sendBar(ChatUserSummary selected) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        key: const Key('camera-recipient-send-bar'),
        color: colors.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  widget.photoBytes,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filled(
                tooltip: _tr('chat_send'),
                onPressed: () => Navigator.pop(context, selected),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tr(String key) => AppTranslations.translate(context, ref, key);
}
