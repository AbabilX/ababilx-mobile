import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../local_share/widgets/qr_scan_sheet.dart';
import '../../messages/chat-people/scanned_user_sheet.dart';
import '../../messages/chat-people/user_qr_payload.dart';
import '../../messages/history-transfer/history_transfer_approval.dart';
import '../../messages/history-transfer/history_transfer_payload.dart';
import '../../messages/message_e2ee/device_link_approval.dart';
import '../data/qr_login_repository.dart';

/// Scan a QR from another device and act on it.
///
/// Four things can come off the camera, told apart by the `ababilx://` host:
/// a **sign-in** code hands that device a session; a **device-link** code
/// hands it this account's message key, which is the only way a new device can
/// read messages at all — the server has no copy to give it; a
/// **history-transfer** code asks for the messages and files this phone still
/// holds, including the ones the server let go at 180 days; a **user** code is
/// somebody's handle, and opens a chat with them.
///
/// The two device codes show what is being approved first, and declining calls
/// the matching deny endpoint so the waiting device stops immediately rather
/// than sitting on a dead code. A user code approves nothing — it is a public
/// handle, and the sheet it opens is the confirmation.
class QrLoginFlow {
  QrLoginFlow._();

  static Future<void> start(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(qrLoginRepositoryProvider);
    final payload = await QrScanSheet.show(context);
    if (payload == null || !context.mounted) return;

    if (isDeviceLinkPayload(payload)) {
      await DeviceLinkApproval.start(context, ref, payload);
      return;
    }
    if (isHistoryTransferPayload(payload)) {
      await HistoryTransferApproval.start(context, ref, payload);
      return;
    }
    final handle = usernameFromQrPayload(payload);
    if (handle != null) {
      await ScannedUserSheet.open(context, ref, handle);
      return;
    }
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
        title: Text(
          AppTranslations.translate(dialogCtx, ref, 'qr_login_confirm'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.translate(
                dialogCtx,
                ref,
                'qr_login_confirm_body',
              ),
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
            child: Text(
              AppTranslations.translate(dialogCtx, ref, 'qr_login_reject'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              AppTranslations.translate(dialogCtx, ref, 'qr_login_approve'),
            ),
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
