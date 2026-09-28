import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat-pins/header_search_field.dart';
import '../../messages/chat_icon.dart';
import 'calls_list_chrome.dart';

/// The Talks tab's header. Searching swaps the title for the search field and
/// the filters for a close button — the same swap the member list makes.
class CallsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CallsAppBar({
    super.key,
    required this.t,
    required this.searching,
    required this.missedOnly,
    required this.missedCount,
    required this.onSearch,
    required this.onCloseSearch,
    required this.onQuery,
    required this.onAll,
    required this.onMissed,
  });

  final String Function(String key) t;
  final bool searching;
  final bool missedOnly;
  final int missedCount;
  final VoidCallback onSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onQuery;
  final VoidCallback onAll;
  final VoidCallback onMissed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return AppBar(
        titleSpacing: 16,
        title: HeaderSearchField(
          hint: t('calls_search'),
          autofocus: true,
          onChanged: onQuery,
        ),
        actions: [
          IconButton(
            tooltip: t('calls_search_close'),
            onPressed: onCloseSearch,
            icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
          ),
          const SizedBox(width: 8),
        ],
      );
    }
    return AppBar(
      title: Text(t('calls_title')),
      actions: [
        // Lato's capitals sit ~1dp below the centre of their line box, so
        // centred buttons read as higher than "Calls" (measured on device:
        // glyph centres 199 vs 201.5 px). The nudge lines them up optically.
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CallFilterAction(
                icon: Icons.call_rounded,
                label: t('calls_all'),
                selected: !missedOnly,
                onPressed: onAll,
              ),
              Badge(
                isLabelVisible: missedCount > 0,
                label: Text('$missedCount'),
                child: CallFilterAction(
                  icon: Icons.call_missed_rounded,
                  label: t('calls_missed_filter'),
                  selected: missedOnly,
                  onPressed: onMissed,
                ),
              ),
              IconButton(
                tooltip: t('calls_search'),
                onPressed: onSearch,
                icon: const ChatIcon(HugeIcons.strokeRoundedSearch01),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
