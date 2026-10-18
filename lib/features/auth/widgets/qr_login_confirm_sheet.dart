import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../data/qr_login_repository.dart';

/// The single confirmation a one-scan sign-in needs, as a bottom sheet.
///
/// [code] is the six digits over the QR's link key, derived on this phone from
/// what the camera read; the other screen shows the same digits. It is null for
/// a plain sign-in code (an older web or desktop build). There is no history
/// switch: when the code carries a history key, the chats go with the sign-in
/// (user's call, 2026-10-18). True only when the user approved.
Future<bool> showQrLoginConfirmSheet(
  BuildContext context,
  WidgetRef ref, {
  required QrLoginRequest request,
  String? code,
}) async {
  final approved = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _QrLoginConfirmSheet(request: request, code: code),
  );
  return approved == true;
}

class _QrLoginConfirmSheet extends ConsumerWidget {
  const _QrLoginConfirmSheet({required this.request, this.code});

  final QrLoginRequest request;
  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final details = [
      if (request.deviceName.isNotEmpty) request.deviceName,
      if (request.requestIp.isNotEmpty) request.requestIp,
    ].join(' • ');
    final code = this.code;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedComputerPhoneSync,
              size: 32,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              t('qr_login_confirm'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                code == null
                    ? 'qr_login_confirm_body'
                    : 'qr_login_one_scan_body',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                details,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (code != null) ...[
              const SizedBox(height: 20),
              Text(
                t('qr_login_code_hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                '${code.substring(0, 3)} ${code.substring(3)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t('qr_login_approve')),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t('qr_login_reject')),
            ),
          ],
        ),
      ),
    );
  }
}
