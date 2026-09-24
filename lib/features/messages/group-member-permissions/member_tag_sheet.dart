import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import 'group_admin_api.dart';
import 'group_member_tags_provider.dart';
import 'member_tag_editor.dart';
import 'permission_section.dart';

/// Add / edit one member's tag from the member menu: the same preview and
/// field as the User Permissions screen, on a sheet. An admin tags anyone; a
/// member reaches this only for themselves, with Edit Own Tag.
Future<void> showMemberTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ChatMember member,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _MemberTagSheet(conversationId: conversationId, member: member),
  );
}

class _MemberTagSheet extends ConsumerStatefulWidget {
  const _MemberTagSheet({required this.conversationId, required this.member});

  final String conversationId;
  final ChatMember member;

  @override
  ConsumerState<_MemberTagSheet> createState() => _MemberTagSheetState();
}

class _MemberTagSheetState extends ConsumerState<_MemberTagSheet> {
  late final TextEditingController _tag = TextEditingController(
    text: widget.member.tag,
  );
  bool _saving = false;

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final stored = await putMemberTag(
        ref.read(apiClientProvider),
        widget.conversationId,
        widget.member.userId,
        _tag.text.trim(),
      );
      ref
          .read(groupMemberTagsProvider.notifier)
          .setTag(widget.conversationId, widget.member.userId, stored);
      ref
          .read(groupRosterRevisionProvider(widget.conversationId).notifier)
          .state++;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        groupPermissionErrorText(
          context,
          ref,
          error,
          fallbackKey: 'group_tag_failed',
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PermissionSection(
              divider: false,
              footer: t(
                'group_tag_help',
              ).replaceAll('{name}', widget.member.name),
              children: [
                MemberTagEditor(member: widget.member, controller: _tag),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(t('group_tag_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
