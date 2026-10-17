import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../data/session_repository.dart';

/// One linked device: what it is, when it was linked, when it was last seen,
/// and a ⋮ holding the two things that can be done to it.
///
/// The buttons used to sit in the row itself — two labelled actions per device,
/// on every row. Signal puts them behind the overflow because the list is
/// something you read far more often than you act on, and a wall of Rename /
/// Sign out is what made this screen hard to scan.
class SessionTile extends ConsumerWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.busy,
    required this.onRename,
    required this.onRevoke,
  });

  final UserSession session;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meta = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colors.surfaceContainerHigh,
        child: ChatIcon(
          _clientHugeIcon(session.client),
          size: 20,
          color: colors.onSurface,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              session.label,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (session.current) ...[
            const SizedBox(width: 8),
            _Chip(
              text: AppTranslations.translate(
                context,
                ref,
                'devices_this_device',
              ),
              color: colors.primary,
            ),
          ],
          if (session.linked) ...[
            const SizedBox(width: 8),
            _Chip(
              text: AppTranslations.translate(
                context,
                ref,
                'devices_keeps_chats',
              ),
              color: colors.tertiary,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppTranslations.translate(context, ref, 'devices_linked_on')} '
            '${_date(session.createdAt)}',
            style: meta,
          ),
          Text(
            '${AppTranslations.translate(context, ref, 'devices_last_active')} '
            '${_date(session.lastSeenAt)}',
            style: meta,
          ),
        ],
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<_TileAction>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) =>
                  action == _TileAction.rename ? onRename() : onRevoke(),
              itemBuilder: (menuContext) => [
                PopupMenuItem(
                  value: _TileAction.rename,
                  child: Text(
                    AppTranslations.translate(
                      menuContext,
                      ref,
                      'devices_rename',
                    ),
                  ),
                ),
                // The current session is signed out from Settings → Sign out,
                // which also clears this device's message key. Offering it
                // here would be a second door to a different outcome.
                if (!session.current)
                  PopupMenuItem(
                    value: _TileAction.revoke,
                    child: Text(
                      AppTranslations.translate(
                        menuContext,
                        ref,
                        'devices_sign_out',
                      ),
                      style: TextStyle(color: colors.error),
                    ),
                  ),
              ],
            ),
    );
  }
}

enum _TileAction { rename, revoke }

List<List<dynamic>> _clientHugeIcon(String client) {
  if (client == 'mobile') return HugeIcons.strokeRoundedSmartPhone01;
  if (client == 'desktop') return HugeIcons.strokeRoundedComputer;
  return HugeIcons.strokeRoundedInternet;
}

/// A date, not "3 days ago". This list is read to answer "is that laptop still
/// signed in, and is that the one I used in August?" — a relative age answers
/// neither, and Signal shows dates here for the same reason.
String _date(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '—';
  return DateFormat.yMd().format(dt);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
