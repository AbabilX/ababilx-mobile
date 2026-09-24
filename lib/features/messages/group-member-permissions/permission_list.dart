import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';

/// The permission rows both permission pages share, drawn like every other
/// settings switch in the app (`SwitchListTile`, a Hugeicon in front).
///
/// [groupDefaults] is null on the group's own page. On a member's page it is
/// what the group allows: a row the group has off is shown off and disabled,
/// with the reason under it — a member exception can only take away.
class PermissionList extends ConsumerStatefulWidget {
  const PermissionList({
    super.key,
    required this.value,
    required this.onChanged,
    this.groupDefaults,
  });

  final GroupMemberPerms value;
  final ValueChanged<GroupMemberPerms> onChanged;
  final GroupMemberPerms? groupDefaults;

  @override
  ConsumerState<PermissionList> createState() => _PermissionListState();
}

class _PermissionListState extends ConsumerState<PermissionList> {
  bool _mediaOpen = false;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  bool _locked(bool Function(GroupMemberPerms) read) {
    final defaults = widget.groupDefaults;
    return defaults != null && !read(defaults);
  }

  Widget _row(
    List<List<dynamic>> icon,
    String key,
    bool Function(GroupMemberPerms) read,
    GroupMemberPerms Function(bool) write, {
    bool enabled = true,
    double indent = 0,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final locked = _locked(read);
    return SwitchListTile(
      contentPadding: EdgeInsets.only(left: 20 + indent, right: 12),
      secondary: ChatIcon(icon, size: 22, color: muted),
      title: Text(_t(key), style: theme.textTheme.bodyLarge),
      subtitle: locked
          ? Text(
              _t('group_perm_locked_hint'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            )
          : null,
      value: read(widget.value) && enabled && !locked,
      onChanged: enabled && !locked
          ? (on) => widget.onChanged(write(on))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final sendOn = v.sendMessages && !_locked((p) => p.sendMessages);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          HugeIcons.strokeRoundedBubbleChat,
          'group_perm_send_messages',
          (p) => p.sendMessages,
          (on) => v.copyWith(sendMessages: on),
        ),
        _mediaRow(v, sendOn),
        if (_mediaOpen)
          for (final kind in GroupMediaKind.values)
            _row(
              _mediaIcon(kind),
              _mediaKey(kind),
              (p) => p.media(kind),
              (on) => v.withMedia(kind, on),
              enabled: sendOn,
              indent: 24,
            ),
        _row(
          HugeIcons.strokeRoundedUserAdd01,
          'group_perm_add_users',
          (p) => p.addUsers,
          (on) => v.copyWith(addUsers: on),
        ),
        _row(
          HugeIcons.strokeRoundedPin,
          'group_perm_pin',
          (p) => p.pinMessages,
          (on) => v.copyWith(pinMessages: on),
        ),
        _row(
          HugeIcons.strokeRoundedPencilEdit02,
          'group_perm_change_info',
          (p) => p.changeInfo,
          (on) => v.copyWith(changeInfo: on),
        ),
        _row(
          HugeIcons.strokeRoundedCall,
          'group_perm_start_calls',
          (p) => p.startCalls,
          (on) => v.copyWith(startCalls: on),
        ),
        _row(
          HugeIcons.strokeRoundedArrowTurnForward,
          'group_perm_forward',
          (p) => p.forward,
          (on) => v.copyWith(forward: on),
        ),
        _row(
          HugeIcons.strokeRoundedTag01,
          'group_perm_edit_own_tag',
          (p) => p.editOwnTag,
          (on) => v.copyWith(editOwnTag: on),
        ),
      ],
    );
  }

  /// "Send media · 3/4" — tapping the row opens the four kinds; the switch
  /// sets every kind the group leaves open at once.
  Widget _mediaRow(GroupMemberPerms v, bool sendOn) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final open = GroupMediaKind.values
        .where((k) => !_locked((p) => p.media(k)))
        .toList();
    final count = open.where(v.media).length;
    GroupMemberPerms all(bool on) {
      var next = v;
      for (final k in open) {
        next = next.withMedia(k, on);
      }
      return next;
    }

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 12),
      leading: ChatIcon(HugeIcons.strokeRoundedImage01, size: 22, color: muted),
      title: Text(
        _t('group_perm_send_media'),
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        '$count/${GroupMediaKind.values.length}',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      onTap: () => setState(() => _mediaOpen = !_mediaOpen),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatIcon(
            _mediaOpen
                ? HugeIcons.strokeRoundedArrowUp01
                : HugeIcons.strokeRoundedArrowDown01,
            size: 18,
            color: muted,
          ),
          const SizedBox(width: 4),
          Switch(
            value: sendOn && count > 0,
            onChanged: sendOn && open.isNotEmpty
                ? (on) => widget.onChanged(all(on))
                : null,
          ),
        ],
      ),
    );
  }

  List<List<dynamic>> _mediaIcon(GroupMediaKind kind) => switch (kind) {
    GroupMediaKind.photos => HugeIcons.strokeRoundedImage02,
    GroupMediaKind.videos => HugeIcons.strokeRoundedVideo01,
    GroupMediaKind.files => HugeIcons.strokeRoundedFile01,
    GroupMediaKind.music => HugeIcons.strokeRoundedMusicNote01,
  };

  String _mediaKey(GroupMediaKind kind) => switch (kind) {
    GroupMediaKind.photos => 'group_perm_photos',
    GroupMediaKind.videos => 'group_perm_videos',
    GroupMediaKind.files => 'group_perm_files',
    GroupMediaKind.music => 'group_perm_music',
  };
}
