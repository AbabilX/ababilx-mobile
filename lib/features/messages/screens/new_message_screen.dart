import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/providers/profile_provider.dart';
import '../chat-list/create_channel_dialog.dart';
import '../chat-people/personal_group_sheet.dart';
import '../chat-webhook/webhook_create_sheet.dart';
import '../data/models/chat_connection.dart';
import '../new-message/new_message_action.dart';
import '../new-message/new_message_people_list.dart';
import '../new-message/new_message_search.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';
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
    final independent =
        ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
    // A webhook feed is a workspace conversation by construction — the server
    // refuses a personal-scope one — so the row is absent without a workspace
    // rather than failing on tap.
    final hasTeam = ref.watch(hasTeamProvider);
    final connectionState = ref.watch(chatConnectionsProvider);
    final people = _visiblePeople(
      ref.watch(messageablePeopleProvider),
      connectionState.searchResults,
    );
    String tr(String key) => AppTranslations.translate(context, ref, key);

    return Scaffold(
      appBar: AppBar(title: Text(tr('chat_new_message'))),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: NewMessageSearch(
              controller: _search,
              focusNode: _focus,
              hintText: tr('chat_search_people_full'),
              onChanged: _onSearch,
            ),
          ),
          if (connectionState.searching)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                NewMessageAction(
                  icon: Icons.group_outlined,
                  label: tr('chat_new_group'),
                  onTap: () => _newGroup(independent),
                ),
                NewMessageAction(
                  icon: Icons.alternate_email_rounded,
                  label: tr('chat_find_by_username'),
                  onTap: _focusSearch,
                ),
                NewMessageAction(
                  icon: Icons.numbers_rounded,
                  label: tr('chat_find_by_phone'),
                  onTap: _focusSearch,
                ),
                // Last of the actions: the two search hints above answer the
                // question this screen is usually open for, and a feed is set
                // up once and then never again.
                if (hasTeam)
                  NewMessageAction(
                    icon: Icons.link_rounded,
                    label: tr('chat_new_webhook_feed'),
                    onTap: _newWebhookFeed,
                  ),
              ],
            ),
          ),
          NewMessagePeopleList(
            people: people,
            // A failed lookup and a genuinely empty directory used to render
            // identically — a blank list — which is how a 404 from an
            // unregistered /api/chat/* route reads to the user as "nobody
            // matched anything I type".
            emptyTitle: connectionState.error.isEmpty
                ? tr('chat_no_people')
                : tr('chat_search_failed'),
            emptyBody: connectionState.error.isEmpty
                ? tr('chat_no_people_body')
                : connectionState.error,
            onTap: _onPersonTap,
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  void _focusSearch() {
    _focus.requestFocus();
    _search.selection = TextSelection.collapsed(offset: _search.text.length);
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
      // The nickname is searched too: once you have renamed someone whose own
      // name you cannot read, that rename has to be how you find them.
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

  /// One tap, one outcome. Nobody has to be "connected" first — the DM opens,
  /// and if they are a stranger the first message you send becomes a request
  /// they answer at their end.
  Future<void> _onPersonTap(ChatUserSummary user) async {
    final dm = await ref.read(chatProvider.notifier).startDm(user.userId);
    if (mounted) context.pushReplacement('/messages/${dm.id}');
  }

  Future<void> _newWebhookFeed() async {
    final feed = await showWebhookCreateSheet(context, ref);
    if (feed != null && mounted) context.pushReplacement('/messages/${feed.id}');
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
