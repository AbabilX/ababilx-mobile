import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-people/personal_group_sheet.dart';
import '../chat-webhook/webhook_create_sheet.dart';
import '../data/models/chat_connection.dart';
import '../new-message/new_message_action.dart';
import '../new-message/new_message_handle_results.dart';
import '../new-message/new_message_people_list.dart';
import '../new-message/new_message_search.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import '../../../shared/text/name_search.dart';
import '../nickname/contact_nickname_provider.dart';

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  /// "Find by username": the field takes a bare handle behind a grey `@`.
  bool _byUsername = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(chatConnectionsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
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
    final connectionState = ref.watch(chatConnectionsProvider);
    final people = _visiblePeople(
      ref.watch(messageablePeopleProvider),
      connectionState.searchResults,
    );
    String tr(String key) => AppTranslations.translate(context, ref, key);

    final query = _search.text.trim();

    return PopScope(
      // Back leaves username mode before it leaves the screen.
      canPop: !_byUsername,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setUsernameMode(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tr(_byUsername ? 'chat_find_by_username' : 'chat_new_message'),
          ),
        ),
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: NewMessageSearch(
                key: ValueKey(_byUsername),
                controller: _search,
                focusNode: _focus,
                handle: _byUsername,
                hintText: tr(
                  _byUsername
                      ? 'chat_username_hint'
                      : 'chat_search_people_full',
                ),
                helper: _byUsername ? tr('chat_username_help') : null,
                onChanged: _onSearch,
              ),
            ),
            if (connectionState.searching)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_byUsername)
              NewMessageHandleResults(
                query: query,
                searching: connectionState.searching,
                error: connectionState.error,
                people: connectionState.searchResults,
                noneTitle: tr('chat_username_none').replaceAll('{name}', query),
                noneBody: tr('chat_username_none_body'),
                onTap: _onPersonTap,
              )
            else ...[
              SliverToBoxAdapter(
                child: NewMessageActions(
                  onGroup: _newGroup,
                  onUsername: () => _setUsernameMode(true),
                  onFeed: _newWebhookFeed,
                ),
              ),
              NewMessagePeopleList(
                people: people,
                // A failed lookup and an empty directory must not look alike.
                emptyTitle: connectionState.error.isEmpty
                    ? tr('chat_no_people')
                    : tr('chat_search_failed'),
                emptyBody: connectionState.error.isEmpty
                    ? tr('chat_no_people_body')
                    : connectionState.error,
                onTap: _onPersonTap,
              ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  /// Each mode starts from an empty field: a name typed for the local list
  /// is not a handle, and a handle has no use in the local list.
  void _setUsernameMode(bool on) {
    if (_byUsername == on) return;
    _debounce?.cancel();
    _search.clear();
    ref.read(chatConnectionsProvider.notifier).search('');
    setState(() => _byUsername = on);
    _focus.requestFocus();
  }

  List<ChatUserSummary> _visiblePeople(
    List<ChatUserSummary> messageable,
    List<ChatUserSummary> discovered,
  ) {
    final query = _search.text.trim();
    if (query.isEmpty) return messageable;
    final nicknames = ref.read(contactNicknamesProvider);
    final users = <String, ChatUserSummary>{};
    for (final user in [...messageable, ...discovered]) {
      // A nickname is how you find someone whose own name you cannot read.
      final matches = matchesNameQuery(query, [
        nicknames.forUser(user.userId),
        user.name,
        user.username,
      ]);
      if (matches || discovered.contains(user)) users[user.userId] = user;
    }
    final result = users.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// The DM opens; to a stranger the first message is a request.
  Future<void> _onPersonTap(ChatUserSummary user) async {
    final dm = await ref.read(chatProvider.notifier).startDm(user.userId);
    if (mounted) context.pushReplacement('/messages/${dm.id}');
  }

  /// A feed needs no workspace (migration 0128).
  Future<void> _newWebhookFeed() async {
    final feed = await showWebhookCreateSheet(context, ref);
    if (feed != null && mounted) {
      context.pushReplacement('/messages/${feed.id}');
    }
  }

  Future<void> _newGroup() async {
    final group = await showPersonalGroupSheet(context, ref);
    if (group != null && mounted) {
      context.pushReplacement('/messages/${group.id}');
    }
  }
}
