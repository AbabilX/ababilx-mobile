import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/name_search.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat-pins/header_search_field.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import 'call_favorite.dart';
import 'call_favorites_provider.dart';

/// Who can be a favourite: a real person in a DM this account can still call.
/// Note to Self, deleted accounts and locked chats have nobody to ring.
bool canBeCallFavorite(ChatConversation c) =>
    c.hasDmPeer && c.canMessage && !c.isAccountDeleted;

/// "+" on the strip: the chat list's DMs, searchable; a tap adds or removes.
/// Reads the phone's own chat list, so it works offline too.
Future<void> showCallFavoritePicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _CallFavoritePicker(),
    );

class _CallFavoritePicker extends ConsumerStatefulWidget {
  const _CallFavoritePicker();

  @override
  ConsumerState<_CallFavoritePicker> createState() =>
      _CallFavoritePickerState();
}

class _CallFavoritePickerState extends ConsumerState<_CallFavoritePicker> {
  String _query = '';

  Future<void> _toggle(CallFavorite candidate, bool isFavorite, String full) {
    final notifier = ref.read(callFavoritesProvider.notifier);
    if (isFavorite) return notifier.remove(candidate.conversationId);
    return notifier.add(candidate).then((added) {
      if (!added && mounted) showAppToast(context, full, isError: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    String t(String key) => AppTranslations.of(lang, key);
    final chat = ref.watch(chatProvider);
    final nicknames = ref.watch(contactNicknamesProvider);
    final favorites = ref.watch(callFavoritesProvider);
    final people = [
      for (final c in chat.dms)
        if (canBeCallFavorite(c))
          (conversation: c, name: nicknames.titleFor(c, chat.currentUserId)),
    ].where((p) => matchesNameQuery(_query, [p.name])).toList();
    final full = t(
      'calls_favorite_full',
    ).replaceAll('{n}', '${CallFavoritesNotifier.maxFavorites}');

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              t('calls_favorite_pick_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: HeaderSearchField(
              hint: t('calls_favorite_search'),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? Center(child: Text(t('calls_favorite_none')))
                : ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (_, i) {
                      final p = people[i];
                      final id = p.conversation.id;
                      final isFavorite = favorites.any(
                        (f) => f.conversationId == id,
                      );
                      return ListTile(
                        leading: AppAvatar(
                          size: 44,
                          url: p.conversation.peerUserAvatar,
                          name: p.name,
                        ),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isFavorite
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onTap: () => _toggle(
                          CallFavorite.fromConversation(p.conversation, p.name),
                          isFavorite,
                          full,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
