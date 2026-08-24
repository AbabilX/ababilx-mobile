import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/profile_provider.dart';
import '../chat-list/create_channel_dialog.dart';
import '../chat-people/personal_group_sheet.dart';
import '../data/models/chat_connection.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(chatConnectionsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(chatConnectionsProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final independent =
        ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
    final connectionState = ref.watch(chatConnectionsProvider);
    final people = _visiblePeople(
      ref.watch(messageablePeopleProvider),
      connectionState.searchResults,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppTranslations.translate(context, ref, 'chat_new_message'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onSearch,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: AppTranslations.translate(
                  context,
                  ref,
                  'chat_search_people',
                ),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (connectionState.searching)
            const LinearProgressIndicator(minHeight: 2),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group_add_outlined)),
            title: Text(
              AppTranslations.translate(context, ref, 'chat_new_group'),
            ),
            onTap: () => _newGroup(independent),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: people.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (_, index) => _personRow(people[index]),
            ),
          ),
        ],
      ),
    );
  }

  List<ChatUserSummary> _visiblePeople(
    List<ChatUserSummary> messageable,
    List<ChatUserSummary> discovered,
  ) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return messageable;
    final users = <String, ChatUserSummary>{};
    for (final user in [...messageable, ...discovered]) {
      final matches =
          user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
      if (matches || discovered.contains(user)) users[user.userId] = user;
    }
    return users.values.toList();
  }

  Widget _personRow(ChatUserSummary user) {
    final pending =
        user.connection == 'pending_in' || user.connection == 'pending_out';
    return ListTile(
      leading: AppAvatar(size: 48, url: user.avatarUrl, name: user.name),
      title: Text(user.name),
      subtitle: user.username.isEmpty ? null : Text('@${user.username}'),
      trailing: pending
          ? Text(AppTranslations.translate(context, ref, 'chat_pending'))
          : user.canMessage
          ? null
          : const Icon(Icons.person_add_alt_1_rounded),
      onTap: () => user.canMessage ? _startDm(user) : _connect(user, pending),
    );
  }

  Future<void> _startDm(ChatUserSummary user) async {
    final dm = await ref.read(chatProvider.notifier).startDm(user.userId);
    if (mounted) context.pushReplacement('/messages/${dm.id}');
  }

  Future<void> _connect(ChatUserSummary user, bool pending) async {
    if (pending) return;
    await ref.read(chatConnectionsProvider.notifier).sendRequest(user.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.translate(context, ref, 'chat_request_sent'),
        ),
      ),
    );
  }

  Future<void> _newGroup(bool independent) async {
    final group = independent
        ? await showPersonalGroupSheet(context, ref)
        : await showCreateChannelDialog(context, ref);
    if (group != null && mounted) {
      context.pushReplacement('/messages/${group.id}');
    }
  }
}
