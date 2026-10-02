import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/qr_login_repository.dart';

/// What the user chose in the one sign-in dialog.
class QrLoginChoice {
  const QrLoginChoice({required this.approved, this.sendHistory = false});
  final bool approved;
  final bool sendHistory;
}

/// The single confirmation a one-scan sign-in needs.
///
/// [code] is the six digits over the QR's link key, derived on this phone from
/// what the camera read; the other screen shows the same digits. It is null for
/// a plain sign-in code (an older web or desktop build), and so is the history
/// switch when the code carried no history key.
Future<QrLoginChoice> showQrLoginConfirmDialog(
  BuildContext context,
  WidgetRef ref, {
  required QrLoginRequest request,
  String? code,
  bool offerHistory = false,
}) async {
  var sendHistory = offerHistory;
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) {
        final theme = Theme.of(dialogCtx);
        final colors = theme.colorScheme;
        String t(String key) => AppTranslations.translate(dialogCtx, ref, key);
        final details = [
          if (request.deviceName.isNotEmpty) request.deviceName,
          if (request.requestIp.isNotEmpty) request.requestIp,
        ].join(' • ');
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: colors.outline),
          ),
          title: Text(t('qr_login_confirm')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  code == null
                      ? 'qr_login_confirm_body'
                      : 'qr_login_one_scan_body',
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
              if (code != null) ...[
                const SizedBox(height: 14),
                Text(t('qr_login_code_hint'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                  '${code.substring(0, 3)} ${code.substring(3)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (offerHistory) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendHistory,
                  onChanged: (value) => setState(() => sendHistory = value),
                  title: Text(t('qr_login_send_history')),
                  subtitle: Text(t('qr_login_send_history_body')),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(t('qr_login_reject')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(t('qr_login_approve')),
            ),
          ],
        );
      },
    ),
  );
  return QrLoginChoice(approved: approved == true, sendHistory: sendHistory);
}
