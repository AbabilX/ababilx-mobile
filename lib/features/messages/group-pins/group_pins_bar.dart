import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../../../core/localization/app_translations.dart';
import '../chat-timeline/pinned_message_actions.dart';
import '../group-member-permissions/group_admin_api.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'group_pin_actions.dart';
import 'group_pins_provider.dart';

/// Telegram's pinned bar: the group's shared pins (server 0157), one at a
/// time, over the top of the timeline. A tap jumps to the message shown and
/// steps to the next older pin, so repeated taps walk the list; whoever may
/// pin gets an unpin cross. Draws nothing outside a group or with no pins.
class GroupPinsBar extends ConsumerStatefulWidget {
  const GroupPinsBar({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<GroupPinsBar> createState() => _GroupPinsBarState();
}

class _GroupPinsBarState extends ConsumerState<GroupPinsBar> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isGroup = ref.watch(
      chatProvider.select(
        (c) => c.conversationById(widget.conversationId)?.type == 'group',
      ),
    );
    if (!isGroup) return const SizedBox.shrink();
    final page = ref
        .watch(groupPinsProvider(widget.conversationId))
        .valueOrNull;
    final pins = page?.pins ?? const <GroupPin>[];
    if (pins.isEmpty) return const SizedBox.shrink();
    final index = _index % pins.length;
    final pin = pins[index];
    final colors = Theme.of(context).colorScheme;
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final title = pins.length == 1
        ? tr('group_pin_bar_title')
        : '${tr('group_pin_bar_title')} #${pins.length - index}';
    return Material(
      color: colors.surfaceContainer,
      elevation: 1,
      child: InkWell(
        onTap: () {
          jumpToPinnedMessage(context, ref, pin.message.id);
          setState(() => _index = index + 1);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              _Ticks(count: pins.length, current: index),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _preview(pin, tr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurface, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (page?.canPin == true)
                IconButton(
                  tooltip: tr('group_pin_unpin_all'),
                  icon: const ChatIcon(HugeIcons.strokeRoundedPinOff, size: 20),
                  onPressed: () => setGroupPinned(
                    context,
                    ref,
                    widget.conversationId,
                    pin.message.id,
                    pinned: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(GroupPin pin, String Function(String) tr) {
    final text = tiptapToPreviewText(pin.message.body).trim();
    if (text.isNotEmpty) return text;
    if (pin.message.attachments.isNotEmpty) return tr('group_pin_bar_media');
    return tr('group_pin_bar_message');
  }
}

/// The segmented edge Telegram draws: one tick per pin, the shown one lit.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shown = count > 4 ? 4 : count;
    // Newest is index 0; the ticks read top-down oldest to newest.
    final lit = shown - 1 - (current % shown);
    return SizedBox(
      width: 3,
      height: 36,
      child: Column(
        children: [
          for (var i = 0; i < shown; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: i == lit
                      ? colors.primary
                      : colors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
