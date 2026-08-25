import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/session_repository.dart';
import '../providers/sessions_provider.dart';
import '../widgets/session_rename_dialog.dart';
import '../widgets/session_tile.dart';

/// Signed-in devices, with a way to name one and to sign any of them out.
///
/// QR login makes adding a device a two-second act, so the account needs the
/// matching ability to take one away — including from a device the user no
/// longer has in hand.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppTranslations.translate(context, ref, 'devices_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: colors.primary,
            strokeWidth: 2.5,
          ),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppTranslations.translate(context, ref, 'devices_error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
          ),
        ),
        data: (sessions) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              AppTranslations.translate(context, ref, 'devices_subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              Text(
                AppTranslations.translate(context, ref, 'devices_empty'),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            for (final s in sessions)
              SessionTile(
                session: s,
                busy: _busyId == s.id,
                onRename: () => _rename(s),
                onRevoke: () => _revoke(s),
              ),
            if (sessions.where((s) => !s.current).isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busyId == null ? _revokeOthers : null,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  AppTranslations.translate(
                    context,
                    ref,
                    'devices_sign_out_others',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _rename(UserSession session) async {
    final name = await showSessionRenameDialog(
      context,
      ref,
      currentLabel: session.label,
    );
    if (name == null || !mounted) return;
    setState(() => _busyId = session.id);
    final label = await ref
        .read(sessionsProvider.notifier)
        .rename(session.id, name);
    if (!mounted) return;
    setState(() => _busyId = null);
    _toast(label == null ? 'devices_rename_failed' : 'devices_renamed');
  }

  Future<void> _revoke(UserSession session) async {
    final confirmed = await _confirm('devices_sign_out_confirm');
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = session.id);
    final ok = await ref.read(sessionsProvider.notifier).revoke(session.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _toast(ok ? 'devices_signed_out' : 'devices_sign_out_failed');
  }

  Future<void> _revokeOthers() async {
    final confirmed = await _confirm('devices_sign_out_others_confirm');
    if (confirmed != true || !mounted) return;
    final revoked = await ref.read(sessionsProvider.notifier).revokeOthers();
    if (!mounted) return;
    _toast(
      revoked == null ? 'devices_sign_out_failed' : 'devices_signed_out_others',
    );
  }

  Future<bool?> _confirm(String messageKey) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Text(AppTranslations.translate(dialogCtx, ref, messageKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(AppTranslations.translate(dialogCtx, ref, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
            ),
            child: Text(
              AppTranslations.translate(dialogCtx, ref, 'devices_sign_out'),
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.translate(context, ref, key))),
    );
  }
}
