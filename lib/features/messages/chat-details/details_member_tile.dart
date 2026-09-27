import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import '../group-member-permissions/member_actions_menu.dart';
import 'avatar_preview.dart';

/// One roster row, shared by the details preview and the full members page:
/// face, name, "Restricted" for an admin's eyes, the tag (else "Admin") on
/// the right. Tapping the row opens the member sheet.
class DetailsMemberTile extends ConsumerWidget {
  const DetailsMemberTile({
    super.key,
    required this.conversation,
    required this.member,
  });

  final ChatConversation conversation;
  final ChatMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minVerticalPadding: 10,
      leading: _avatar(context),
      title: Text(
        member.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      // An admin sees who an admin restricted (server 0157).
      subtitle: member.restricted
          ? Text(
              AppTranslations.translate(
                context,
                ref,
                'group_perm_restricted_label',
              ),
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 0,
                color: colors.onSurfaceVariant,
              ),
            )
          : null,
      // Telegram's right side: the member's tag, else "Admin".
      trailing: _roleLabel(colors),
      onTap: () => showGroupMemberMenu(
        context: context,
        ref: ref,
        conversation: conversation,
        member: member,
      ),
    );
  }

  Widget? _roleLabel(ColorScheme colors) {
    final label = member.tag.isNotEmpty
        ? member.tag
        : member.isAdmin
        ? 'Admin'
        : null;
    if (label == null) return null;
    // A tag is free text (Bangla often): capped so a long one never pushes
    // the name out, and letterSpacing 0 — Material's 0.5 on this slot pulls
    // Bengali vowel signs off their consonants.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: member.isAdmin ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }

  /// The face opens the picture; the rest of the row still opens the
  /// member sheet. A letter fallback has no photo, so it stays on the row.
  Widget _avatar(BuildContext context) {
    final photo = ClipOval(
      child: AppAvatar(size: 42, url: member.avatarUrl, name: member.name),
    );
    if (previewPhotoUrl(member.avatarUrl) == null) return photo;
    return Semantics(
      button: true,
      label: 'View photo',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('member-avatar-preview-${member.userId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openAvatarPreview(
          context,
          url: member.avatarUrl,
          name: member.name,
        ),
        child: photo,
      ),
    );
  }
}
