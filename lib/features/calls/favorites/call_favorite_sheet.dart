import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import 'call_favorite.dart';
import 'call_favorites_provider.dart';

enum _FavoriteAction { toggle, openChat }

/// Long press on a favourite, or on a 1:1 row in the call history: add or
/// remove it, or open the chat. A bottom sheet, never a popup menu.
Future<void> showCallFavoriteSheet(
  BuildContext context,
  WidgetRef ref,
  CallFavorite favorite,
) async {
  if (favorite.conversationId.isEmpty) return;
  final lang = ref.read(appLanguageProvider);
  String t(String key) => AppTranslations.of(lang, key);
  final notifier = ref.read(callFavoritesProvider.notifier);
  final isFavorite = notifier.contains(favorite.conversationId);
  final action = await showModalBottomSheet<_FavoriteAction>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
            ),
            title: Text(
              t(isFavorite ? 'calls_favorite_remove' : 'calls_favorite_add_to'),
            ),
            onTap: () => Navigator.of(sheet).pop(_FavoriteAction.toggle),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: Text(t('calls_favorite_open_chat')),
            onTap: () => Navigator.of(sheet).pop(_FavoriteAction.openChat),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _FavoriteAction.openChat:
      context.push('/messages/${favorite.conversationId}');
    case _FavoriteAction.toggle:
      if (isFavorite) {
        await notifier.remove(favorite.conversationId);
        return;
      }
      final added = await notifier.add(favorite);
      if (!added && context.mounted) {
        showAppToast(
          context,
          t(
            'calls_favorite_full',
          ).replaceAll('{n}', '${CallFavoritesNotifier.maxFavorites}'),
          isError: true,
        );
      }
  }
}
