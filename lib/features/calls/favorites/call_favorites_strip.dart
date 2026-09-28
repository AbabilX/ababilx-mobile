import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../calls-list/call_redial.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_favorite_picker.dart';
import 'call_favorite_sheet.dart';
import 'call_favorite_tile.dart';
import 'call_favorites_provider.dart';

/// Favourites at the top of the Talks tab: one tap places the call.
///
/// Everything it draws is on the phone (see [CallFavoritesNotifier]), so it is
/// there offline and before the history loads; only the call itself needs the
/// network. Long press for remove / open chat; "+" opens the picker.
class CallFavoritesStrip extends ConsumerWidget {
  const CallFavoritesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(callFavoritesProvider);
    final lang = ref.watch(appLanguageProvider);
    final busy =
        ref.watch(voiceCallProvider.select((s) => s.active)) ||
        ref.watch(groupCallProvider.select((s) => s.active));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            itemCount: favorites.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == favorites.length) {
                return CallFavoriteAddTile(
                  label: AppTranslations.of(lang, 'calls_favorite_add'),
                  onTap: () => showCallFavoritePicker(context),
                );
              }
              final favorite = favorites[i];
              return CallFavoriteTile(
                favorite: favorite,
                // redialCall calls when the chat is on the phone, else opens it.
                onTap: busy
                    ? null
                    : () => redialCall(
                        context,
                        ref,
                        favorite.conversationId,
                        isGroup: false,
                      ),
                onLongPress: () =>
                    showCallFavoriteSheet(context, ref, favorite),
              );
            },
          ),
        ),
      ],
    );
  }
}
