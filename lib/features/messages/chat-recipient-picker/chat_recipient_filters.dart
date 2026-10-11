import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_capsule.dart';
import 'chat_recipient_sections.dart';

/// The capsules under the search field: All · Chats · Groups · Contacts.
class ChatRecipientFilters extends StatelessWidget {
  const ChatRecipientFilters({
    super.key,
    required this.filter,
    required this.labels,
    required this.enabled,
    required this.onChanged,
  });

  final ChatRecipientFilter filter;
  final Map<ChatRecipientFilter, String> labels;
  final bool enabled;
  final ValueChanged<ChatRecipientFilter> onChanged;

  static final _icons = <ChatRecipientFilter, List<List<dynamic>>>{
    ChatRecipientFilter.chats: HugeIcons.strokeRoundedBubbleChat,
    ChatRecipientFilter.groups: HugeIcons.strokeRoundedUserGroup,
    ChatRecipientFilter.contacts: HugeIcons.strokeRoundedUserMultiple,
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: ChatRecipientFilter.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final option = ChatRecipientFilter.values[index];
        final selected = option == filter;
        return AppCapsule(
          label: labels[option] ?? option.name,
          icon: _icons[option],
          selected: selected,
          // A selected capsule stays lit while sending; the rest dim.
          onTap: enabled ? () => onChanged(option) : null,
        );
      },
    ),
  );
}
