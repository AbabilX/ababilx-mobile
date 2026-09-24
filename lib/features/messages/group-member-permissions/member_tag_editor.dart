import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-timeline/sender_name_color.dart';
import '../data/models/chat_models.dart';

/// Max runes the server keeps (`groupperms.MaxTagRunes`).
const int maxMemberTagLength = 16;

/// The tag field, in the app's form style, with the sender line it will
/// produce underneath — the name in its chat colour and the tag beside it,
/// exactly as the timeline draws it.
class MemberTagEditor extends ConsumerWidget {
  const MemberTagEditor({
    super.key,
    required this.member,
    required this.controller,
  });

  final ChatMember member;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            maxLength: maxMemberTagLength,
            inputFormatters: [
              LengthLimitingTextInputFormatter(maxMemberTagLength),
            ],
            decoration: InputDecoration(
              labelText: t('group_tag_title'),
              hintText: t('group_tag_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final tag = value.text.trim();
              return Row(
                children: [
                  Flexible(
                    child: Text(
                      member.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: senderNameColor(member.userId),
                      ),
                    ),
                  ),
                  if (tag.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(tag, style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
