import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/data/session_repository.dart';
import '../../profile/providers/sessions_provider.dart';
import '../data/linked_device_limit.dart';

/// Runs [approve]; when the account already has its linked web and desktop
/// devices (server 0174) shows them so one can be signed out, then approves
/// the same code again. The server refuses before approving anything, so the
/// retry is the same sign-in, not a new one. False when the user backed out.
Future<bool> approveMakingRoom(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() approve,
) async {
  while (true) {
    try {
      await approve();
      return true;
    } on LinkedDeviceLimit catch (limit) {
      if (!context.mounted) return false;
      final freed = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _LinkedLimitSheet(limit: limit),
      );
      if (freed != true || !context.mounted) return false;
    }
  }
}

class _LinkedLimitSheet extends ConsumerStatefulWidget {
  const _LinkedLimitSheet({required this.limit});

  final LinkedDeviceLimit limit;

  @override
  ConsumerState<_LinkedLimitSheet> createState() => _LinkedLimitSheetState();
}

class _LinkedLimitSheetState extends ConsumerState<_LinkedLimitSheet> {
  String? _busy;
  bool _failed = false;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _signOut(LinkedDeviceSummary device) async {
    setState(() {
      _busy = device.sessionId;
      _failed = false;
    });
    try {
      await ref.read(sessionRepositoryProvider).revoke(device.sessionId);
      ref.invalidate(sessionsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final limit = widget.limit;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  ChatIcon(
                    HugeIcons.strokeRoundedComputerPhoneSync,
                    size: 32,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('linked_limit_title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('linked_limit_body')
                        .replaceAll('{limit}', '${limit.limit}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final device in limit.devices) _row(device, colors),
                ],
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Text(
                  _t('devices_sign_out_failed'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy == null
                    ? () => Navigator.of(context).pop(false)
                    : null,
                child: Text(_t('cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(LinkedDeviceSummary device, ColorScheme colors) {
    final busy = _busy == device.sessionId;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: ChatIcon(
        device.platform == 'desktop'
            ? HugeIcons.strokeRoundedComputer
            : HugeIcons.strokeRoundedInternet,
        size: 22,
        color: colors.onSurface,
      ),
      title: Text(
        device.label.isNotEmpty ? device.label : device.platform,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_t('devices_last_active')} ${_date(device.lastSeenAt)}',
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _busy == null && device.sessionId.isNotEmpty
                  ? () => _signOut(device)
                  : null,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text(_t('devices_sign_out')),
            ),
    );
  }
}

String _date(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  return dt == null ? '—' : DateFormat.yMd().format(dt);
}
