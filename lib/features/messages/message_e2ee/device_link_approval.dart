import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import 'message_vault.dart';
import '../../../shared/widgets/app_toast.dart';

const _linkScheme = 'ababilx://link-messages';

/// One scanned device-link request, as read off the camera.
///
/// The ephemeral public key comes out of the QR itself and is never fetched
/// from the server — that is precisely what stops the server substituting a key
/// of its own and reading everything that follows.
class ScannedLinkRequest {
  const ScannedLinkRequest({required this.token, required this.publicKeyParam});
  final String token;
  final String publicKeyParam;
}

bool isDeviceLinkPayload(String raw) => raw.trim().startsWith(_linkScheme);

ScannedLinkRequest? parseDeviceLinkPayload(String raw) {
  final value = raw.trim();
  if (!value.startsWith(_linkScheme)) return null;
  final query = value.substring(value.indexOf('?') + 1);
  String? token;
  String? key;
  for (final part in query.split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final name = part.substring(0, eq);
    final content = part.substring(eq + 1);
    if (name == 't') token = content;
    if (name == 'k') key = content;
  }
  if (token == null || key == null || token.isEmpty || key.isEmpty) return null;
  return ScannedLinkRequest(token: token, publicKeyParam: key);
}

/// Hands this device's message identity to a device the user has just scanned.
class DeviceLinkApproval {
  DeviceLinkApproval._();

  static Future<void> start(
    BuildContext context,
    WidgetRef ref,
    String payload,
  ) async {
    final request = parseDeviceLinkPayload(payload);
    if (request == null) {
      _toast(context, 'That code is not a device link.');
      return;
    }
    final vault = ref.read(messageVaultProvider);
    if (!vault.isUnlocked && !await vault.restoreTrustedIdentity()) {
      if (context.mounted) {
        _toast(context, 'Open your messages on this device first.');
      }
      return;
    }
    final repo = ref.read(chatRepositoryProvider);

    String deviceName;
    try {
      final info = await repo.inspectE2eeLink(request.token);
      deviceName = (info['device_name'] ?? '').toString();
    } catch (error) {
      // This used to report EVERY failure as "expired" — a 401, a 500, a dead
      // network and a genuinely stale code all read the same, so the one
      // message people saw named the one cause that was usually not it.
      if (context.mounted) _toast(context, _linkFailureMessage(error));
      return;
    }
    if (!context.mounted) return;

    final publicJwk = vault.decodeLinkPublicKey(request.publicKeyParam);
    final code = await vault.linkVerificationCode(publicJwk);
    if (!context.mounted) return;

    final approved = await _confirm(context, deviceName, code);
    if (!context.mounted) return;

    try {
      if (approved == true) {
        await repo.approveE2eeLink(
          request.token,
          await vault.sealIdentityForDevice(publicJwk),
        );
        if (context.mounted) _toast(context, 'Device linked.');
      } else {
        await repo.denyE2eeLink(request.token);
      }
    } catch (error) {
      if (context.mounted) _toast(context, _linkFailureMessage(error));
    }
  }

  static Future<bool?> _confirm(
    BuildContext context,
    String deviceName,
    String code,
  ) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Give this device your messages?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName.isEmpty
                  ? 'A device is asking for your message key.'
                  : '$deviceName is asking for your message key.',
            ),
            const SizedBox(height: 14),
            Text(
              'Only continue if this code matches the one on that screen.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Link device'),
          ),
        ],
      ),
    );
  }

  /// The server answers 410 for a stale code, a consumed one AND one belonging
  /// to another account — deliberately, so a stranger's token reveals nothing.
  /// The message says so rather than picking one of the three and sounding
  /// certain.
  static String _linkFailureMessage(Object error) {
    final status = error is DioException ? error.response?.statusCode : null;
    if (status == 410) {
      return 'That code has expired, or it belongs to a different account.';
    }
    if (status == 401 || status == 403) {
      return 'Sign in again on this phone, then scan once more.';
    }
    if (status == null) {
      return 'Could not reach the server. Check your connection.';
    }
    return 'Could not read that code (error $status).';
  }

  static void _toast(BuildContext context, String message) =>
      showAppToast(context, message);
}
