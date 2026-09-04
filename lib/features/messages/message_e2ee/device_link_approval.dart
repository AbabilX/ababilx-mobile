import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import 'message_vault.dart';

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
    } catch (_) {
      if (context.mounted) _toast(context, 'That link code has expired.');
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
    } catch (_) {
      if (context.mounted) _toast(context, 'Could not link that device.');
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

  static void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
}
