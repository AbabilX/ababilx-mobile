import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../local_share/widgets/qr_scan_sheet.dart';
import '../data/qr_login_repository.dart';

/// Scan a desktop/web sign-in QR, confirm it is really the user, then approve.
/// Declining calls the deny endpoint so the waiting device stops immediately.
class QrLoginFlow {
  QrLoginFlow._();

  static Future<void> start(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(qrLoginRepositoryProvider);
    final payload = await QrScanSheet.show(context);
    if (payload == null || !context.mounted) return;

    if (!repo.isLoginPayload(payload)) {
      _toast(context, ref, 'qr_login_invalid');
      return;
    }

    QrLoginRequest request;
    try {
      request = await repo.inspect(payload);
    } on QrLoginExpired {
      if (context.mounted) _toast(context, ref, 'qr_login_expired');
      return;
    } catch (_) {
      if (context.mounted) _toast(context, ref, 'qr_login_failed');
      return;
    }
    if (!context.mounted) return;

    final approved = await _confirm(context, ref, request);
    if (!context.mounted) return;

    try {
      if (approved == true) {
        await repo.approve(payload);
        if (context.mounted) _toast(context, ref, 'qr_login_done');
      } else {
        await repo.deny(payload);
      }
    } on QrLoginExpired {
      if (context.mounted) _toast(context, ref, 'qr_login_expired');
    } catch (_) {
      if (context.mounted) _toast(context, ref, 'qr_login_failed');
    }
  }

  static Future<bool?> _confirm(
    BuildContext context,
    WidgetRef ref,
    QrLoginRequest request,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = [
      if (request.deviceName.isNotEmpty) request.deviceName,
      if (request.requestIp.isNotEmpty) request.requestIp,
    ].join(' • ');
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.outline),
        ),
        title: Text(AppTranslations.translate(dialogCtx, ref, 'qr_login_confirm')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.translate(dialogCtx, ref, 'qr_login_confirm_body'),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(AppTranslations.translate(dialogCtx, ref, 'qr_login_reject')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(AppTranslations.translate(dialogCtx, ref, 'qr_login_approve')),
          ),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, WidgetRef ref, String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.translate(context, ref, key))),
    );
  }
}
