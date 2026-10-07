import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../data/session_repository.dart';
import '../providers/sessions_provider.dart';
import '../widgets/devices_hero.dart';
import '../widgets/devices_notes.dart';
import '../widgets/session_rename_dialog.dart';
import '../widgets/session_tile.dart';
import '../../../shared/widgets/app_toast.dart';

/// Linked devices — Signal's screen of the same name.
///
/// Pinned hero (link + sign-out-others) above a scrolling list of what is
/// already linked, then the note that messages on all of them are encrypted.
/// "Link a new device" opens the scanner — the same act as approving a
/// desktop sign-in: the code on the other screen is what this phone reads.
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
    final hasOthers =
        sessionsAsync.valueOrNull?.any((s) => !s.current) ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(_t('devices_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
          ),
        ],
      ),
      // Hero + Link / Sign-out-others stay pinned; only the device list scrolls.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DevicesHero(
            caption: _t('devices_hero'),
            buttonLabel: _t('devices_link_new'),
            onLink: () => QrLoginFlow.start(context, ref),
            signOutOthersLabel: _t('devices_sign_out_others'),
            onSignOutOthers: hasOthers ? _revokeOthers : null,
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    _t('devices_my'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...sessionsAsync.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (_, _) => [
                    DevicesNote(_t('devices_error'), color: colors.error),
                  ],
                  data: (sessions) => [
                    if (sessions.isEmpty) DevicesNote(_t('devices_empty')),
                    for (final session in sessions)
                      SessionTile(
                        session: session,
                        busy: _busyId == session.id,
                        onRename: () => _rename(session),
                        onRevoke: () => _revoke(session),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                DevicesEncryptionNote(text: _t('devices_e2ee_note')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _t(String key) => AppTranslations.translate(context, ref, key);

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
    showAppToast(context, AppTranslations.translate(context, ref, key));
  }
}
