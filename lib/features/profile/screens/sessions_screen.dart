import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../messages/chat-pins/pinned_messages_chrome.dart';
import '../../messages/chat_icon.dart';
import '../data/session_repository.dart';
import '../providers/sessions_provider.dart';
import '../widgets/devices_hero.dart';
import '../widgets/devices_notes.dart';
import '../widgets/session_rename_dialog.dart';
import '../widgets/session_tile.dart';

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

enum _DeviceFilter { all, mobile, web, desktop }

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _busyId;
  _DeviceFilter _deviceFilter = _DeviceFilter.all;

  void _toggleFilter() {
    setState(() {
      switch (_deviceFilter) {
        case _DeviceFilter.all:
          _deviceFilter = _DeviceFilter.mobile;
          break;
        case _DeviceFilter.mobile:
          _deviceFilter = _DeviceFilter.web;
          break;
        case _DeviceFilter.web:
          _deviceFilter = _DeviceFilter.desktop;
          break;
        case _DeviceFilter.desktop:
          _deviceFilter = _DeviceFilter.all;
          break;
      }
    });
  }

  List<List<dynamic>> get _filterIcon {
    switch (_deviceFilter) {
      case _DeviceFilter.all:
        return HugeIcons.strokeRoundedComputerPhoneSync;
      case _DeviceFilter.mobile:
        return HugeIcons.strokeRoundedSmartPhone01;
      case _DeviceFilter.web:
        return HugeIcons.strokeRoundedInternet;
      case _DeviceFilter.desktop:
        return HugeIcons.strokeRoundedComputer;
    }
  }

  String get _filterTooltip {
    switch (_deviceFilter) {
      case _DeviceFilter.all:
        return 'All devices';
      case _DeviceFilter.mobile:
        return 'Mobile';
      case _DeviceFilter.web:
        return 'Web';
      case _DeviceFilter.desktop:
        return 'Desktop';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sessionsAsync = ref.watch(sessionsProvider);
    final hasOthers =
        sessionsAsync.valueOrNull?.any((s) => !s.current) ?? false;

    return Scaffold(
      // Hero + Link / Sign-out-others stay pinned; only the device list scrolls.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinnedMessagesTopBar(
            title: _t('devices_title'),
            bottomPadding: 8,
            middle: Center(
              child: Text(
                _t('devices_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          DevicesHero(
            caption: _t('devices_hero'),
            buttonLabel: _t('devices_link_new'),
            onLink: () => QrLoginFlow.start(context, ref),
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
                  data: (sessions) {
                    final filtered = _deviceFilter == _DeviceFilter.all
                        ? sessions
                        : sessions
                            .where((s) => s.client.toLowerCase() == _deviceFilter.name)
                            .toList();
                    return [
                      if (filtered.isEmpty)
                        DevicesNote(
                          _deviceFilter == _DeviceFilter.all
                              ? _t('devices_empty')
                              : 'No ${_filterTooltip.toLowerCase()} devices signed in.',
                        ),
                      for (final session in filtered)
                        SessionTile(
                          session: session,
                          busy: _busyId == session.id,
                          onRename: () => _rename(session),
                          onRevoke: () => _revoke(session),
                        ),
                    ];
                  },
                ),
                const SizedBox(height: 24),
                DevicesEncryptionNote(text: _t('devices_e2ee_note')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: colors.surfaceContainerHigh,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  InkWell(
                    onTap: _toggleFilter,
                    child: Tooltip(
                      message: _filterTooltip,
                      child: SizedBox(
                        width: 48,
                        height: 52,
                        child: Center(
                          child: ChatIcon(
                            _filterIcon,
                            size: 20,
                            color: _deviceFilter == _DeviceFilter.all
                                ? colors.onSurfaceVariant
                                : colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: hasOthers ? _revokeOthers : null,
                      child: Center(
                        child: Opacity(
                          opacity: hasOthers ? 1.0 : 0.38,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: colors.error,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _t('devices_sign_out_others'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: colors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () =>
                          ref.read(sessionsProvider.notifier).refresh(),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChatIcon(
                              HugeIcons.strokeRoundedRefresh,
                              size: 18,
                              color: colors.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _t('devices_refresh'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final confirmed = await _confirm(
      'devices_sign_out_confirm',
      titleKey: 'devices_sign_out',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = session.id);
    final ok = await ref.read(sessionsProvider.notifier).revoke(session.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _toast(ok ? 'devices_signed_out' : 'devices_sign_out_failed');
  }

  Future<void> _revokeOthers() async {
    final confirmed = await _confirm(
      'devices_sign_out_others_confirm',
      titleKey: 'devices_sign_out_others',
    );
    if (confirmed != true || !mounted) return;
    final revoked = await ref.read(sessionsProvider.notifier).revokeOthers();
    if (!mounted) return;
    _toast(
      revoked == null ? 'devices_sign_out_failed' : 'devices_signed_out_others',
    );
  }

  Future<bool?> _confirm(String messageKey, {String? titleKey}) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final colors = Theme.of(sheetCtx).colorScheme;
        final text = Theme.of(sheetCtx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: colors.error,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _t(titleKey ?? 'devices_sign_out_others'),
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(messageKey),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  child: Text(
                    _t('devices_sign_out'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: Text(
                    _t('cancel'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String key) {
    showAppToast(context, AppTranslations.translate(context, ref, key));
  }
}
