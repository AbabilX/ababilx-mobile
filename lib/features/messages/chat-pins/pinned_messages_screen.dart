import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../group-pins/group_pins_provider.dart';
import '../providers/pinned_message_provider.dart';
import '../wallpaper/chat_wallpaper_background.dart';
import 'chat_pin_search.dart';
import 'chat_pin_unpin.dart';
import 'chat_pins_provider.dart';
import 'header_search_field.dart';
import 'pinned_messages_list.dart';
import 'pinned_messages_chrome.dart';
import 'pinned_messages_notice.dart';
import 'unpin_all_fab.dart';
import 'unpin_all_sheet.dart';

/// Every message the caller pinned in one chat, drawn the way Telegram's
/// "N Pinned Messages" does: the chat's wallpaper, the real bubbles in chat
/// order with the newest at the bottom, a go-to arrow beside each, and
/// "Unpin all" floating at the bottom (asks first). Choosing one answers its
/// id to whoever opened this screen, which walks the chat to it. A group lists its
/// shared pins here too, marked "Pinned for everyone" — there is no pin bar
/// over the timeline, in a group or a DM.
class PinnedMessagesScreen extends ConsumerStatefulWidget {
  const PinnedMessagesScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<PinnedMessagesScreen> createState() =>
      _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState extends ConsumerState<PinnedMessagesScreen> {
  bool _unpinningAll = false;
  bool _searching = false;
  String _query = '';

  void _closeSearch() => setState(() {
    _searching = false;
    _query = '';
  });

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    final pins = ref.watch(chatPinsProvider(id));
    final view = pins.valueOrNull ?? const ChatPinsView();
    final unpinnable = view.entries.where(view.canUnpin).length;
    final title = switch (view.entries.length) {
      0 => _tr('chat_pinned_messages'),
      1 => _tr('chat_pins_title_one'),
      final n => _tr('chat_pins_title').replaceAll('{count}', '$n'),
    };
    // Unpin all acts on every pin, so it steps aside while a search narrows
    // the list — a filtered page must not look like what it would clear.
    final fab = unpinnable > 0 && !_searching;
    final page = Scaffold(
      // Unpin all floats bottom centre; the header is the group members
      // page's: back, title capsule, search on the right.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !fab
          ? null
          : UnpinAllFab(
              label: _tr('chat_unpin_all_short'),
              onPressed: _unpinningAll
                  ? null
                  : () => _unpinAll(view, unpinnable),
            ),
      body: ChatWallpaperBackground(
        conversationId: id,
        child: Stack(
          children: [
            Positioned.fill(child: _body(pins, view, fab: fab)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedMessagesTopBar(
                title: title,
                middle: _searching
                    ? HeaderSearchField(
                        hint: _tr('chat_pins_search'),
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                      )
                    : null,
                trailing: view.entries.isEmpty
                    ? null
                    : PinnedMessagesCircleButton(
                        icon: _searching
                            ? HugeIcons.strokeRoundedCancel01
                            : HugeIcons.strokeRoundedSearch01,
                        tooltip: _tr('chat_pins_search'),
                        onPressed: _searching
                            ? _closeSearch
                            : () => setState(() => _searching = true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
    // Back closes the search before it leaves the page.
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: page,
    );
  }

  Widget _body(
    AsyncValue<ChatPinsView> pins,
    ChatPinsView view, {
    required bool fab,
  }) {
    final id = widget.conversationId;
    if (pins.isLoading && !pins.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pins.hasError && !pins.hasValue) {
      return PinnedMessagesNotice(
        title: _tr('chat_pins_load_failed'),
        action: TextButton(
          onPressed: () => ref
            ..invalidate(pinnedMessagesProvider(id))
            ..invalidate(groupPinsProvider(id)),
          child: Text(_tr('recovery_retry')),
        ),
      );
    }
    if (view.entries.isEmpty) {
      return PinnedMessagesNotice(
        title: _tr('chat_pins_empty_title'),
        body: _tr('chat_pins_empty_body'),
      );
    }
    final shown = filterPins(view.entries, _query);
    if (shown.isEmpty) {
      return PinnedMessagesNotice(title: _tr('chat_pins_no_match'));
    }
    return PinnedMessagesList(
      conversationId: id,
      entries: shown,
      view: view,
      fab: fab,
    );
  }

  Future<void> _unpinAll(ChatPinsView view, int count) async {
    final confirmed = await confirmUnpinAll(
      context,
      ref,
      count,
      forEveryone: view.canPinGroup && view.entries.any((e) => e.everyone),
    );
    if (!confirmed || !mounted) return;
    setState(() => _unpinningAll = true);
    final ok = await unpinAllChatPins(
      context,
      ref,
      widget.conversationId,
      view,
    );
    if (!mounted) return;
    setState(() => _unpinningAll = false);
    // A member's own pins can go while the group's stay; close only on empty.
    if (ok && count == view.entries.length) context.pop();
  }
}
