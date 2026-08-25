import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/session_repository.dart';

/// One signed-in device: what it is, when it was last seen, and the two things
/// the user can do to it — name it, or sign it out.
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _clientIcon(session.client),
              size: 19,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      session.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (session.current)
                      _Chip(
                        text: AppTranslations.translate(
                          context,
                          ref,
                          'devices_this_device',
                        ),
                        color: colors.primary,
                      ),
                    if (session.origin == 'qr')
                      _Chip(
                        text: AppTranslations.translate(
                          context,
                          ref,
                          'devices_qr',
                        ),
                        color: colors.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _meta(context, ref, session),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : onRename,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(
                        AppTranslations.translate(
                          context,
                          ref,
                          'devices_rename',
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (!session.current)
                      TextButton.icon(
                        onPressed: busy ? null : onRevoke,
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: Text(
                          AppTranslations.translate(
                            context,
                            ref,
                            'devices_sign_out',
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _clientIcon(String client) {
  if (client == 'mobile') return Icons.smartphone_rounded;
  if (client == 'desktop') return Icons.desktop_windows_rounded;
  return Icons.language_rounded;
}

String _meta(BuildContext context, WidgetRef ref, UserSession s) {
  final active = AppTranslations.translate(context, ref, 'devices_active');
  final ip = s.ip.isNotEmpty ? '${s.ip} · ' : '';
  return '$ip$active ${_ago(s.lastSeenAt)}';
}

/// Deliberately coarse: the list only needs to answer "was this recent?".
String _ago(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '—';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays == 1) return '1 day ago';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${dt.day}/${dt.month}/${dt.year}';
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
