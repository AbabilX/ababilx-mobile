import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../calls-list/call_redial.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/voice_call_provider.dart';
import '../../messages/chat-list/filter_reorder_blur.dart';
import 'call_favorite_picker.dart';
import 'call_favorite_sheet.dart';
import 'call_favorite_tile.dart';
import 'call_favorites_provider.dart';

/// Favourites at the top of the Talks tab: one tap places the call.
///
/// Everything it draws is on the phone (see [CallFavoritesNotifier]), so it is
/// there offline and before the history loads; only the call itself needs the
/// network. Long press for remove / open chat; "+" opens the picker.
class CallFavoritesStrip extends ConsumerStatefulWidget {
  const CallFavoritesStrip({super.key});

  @override
  ConsumerState<CallFavoritesStrip> createState() => _StripState();
}

class _StripState extends ConsumerState<CallFavoritesStrip> {
  int? _heldFrom;

  @override
  Widget build(BuildContext context) {
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
          // Hold a favourite and drag it to arrange them. Held and let go
          // where it was, it opens the same sheet a long press always did.
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            itemCount: favorites.length + 1,
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, child: child),
            onReorderStart: (i) {
              _heldFrom = i;
              filterReordering.value = true;
            },
            onReorderEnd: (i) {
              filterReordering.value = false;
              final from = _heldFrom;
              _heldFrom = null;
              if (from == null || from != i || from >= favorites.length) return;
              // Dropped where it was picked up: a plain hold.
              showCallFavoriteSheet(context, ref, favorites[from]);
            },
            onReorderItem: (from, to) {
              if (from >= favorites.length) return;
              final last = favorites.length - 1;
              ref
                  .read(callFavoritesProvider.notifier)
                  .move(from, to.clamp(0, last).toInt());
            },
            itemBuilder: (context, i) {
              final gap = Padding(
                key: ValueKey(
                  i == favorites.length ? 'add' : favorites[i].conversationId,
                ),
                padding: EdgeInsets.only(right: i == favorites.length ? 0 : 12),
                child: i == favorites.length
                    ? CallFavoriteAddTile(
                        label: AppTranslations.of(lang, 'calls_favorite_add'),
                        onTap: () => showCallFavoritePicker(context),
                      )
                    : ReorderableDelayedDragStartListener(
                        index: i,
                        child: CallFavoriteTile(
                          favorite: favorites[i],
                          // redialCall calls when the chat is on the phone,
                          // else opens it.
                          onTap: busy
                              ? null
                              : () => redialCall(
                                  context,
                                  ref,
                                  favorites[i].conversationId,
                                  isGroup: false,
                                ),
                        ),
                      ),
              );
              return gap;
            },
          ),
        ),
      ],
    );
  }
}
