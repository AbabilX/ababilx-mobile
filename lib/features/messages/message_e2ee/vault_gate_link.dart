import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'device_link_controller.dart';

const _notes = {
  DeviceLinkStatus.loading: 'Preparing a code…',
  DeviceLinkStatus.waiting: 'Waiting for the other device…',
  DeviceLinkStatus.linked: 'Linked. Loading your messages…',
  DeviceLinkStatus.denied: 'That request was rejected on the other device.',
  DeviceLinkStatus.expired: 'This code has expired.',
};

/// Shown when this device has no copy of the account's message key.
///
/// AbabilX has no copy either — that is the point — so it can only come from a
/// device that already holds it. Nothing here asks for a password: scanning is
/// the proof.
class VaultGateLink extends ConsumerStatefulWidget {
  const VaultGateLink({super.key, required this.onLinked});
  final Future<void> Function() onLinked;

  @override
  ConsumerState<VaultGateLink> createState() => _VaultGateLinkState();
}

class _VaultGateLinkState extends ConsumerState<VaultGateLink> {
  bool _handedOff = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final link = ref.watch(deviceLinkControllerProvider);

    if (link.status == DeviceLinkStatus.linked && !_handedOff) {
      _handedOff = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLinked());
    }

    final canRestart =
        link.status == DeviceLinkStatus.expired ||
        link.status == DeviceLinkStatus.denied ||
        link.status == DeviceLinkStatus.error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 16),
              const Text(
                'Link this device',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Open AbabilX on a device where your messages already work, '
                'then scan this code to move your message key across.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 20),
              if (link.payload.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(data: link.payload, size: 208),
                ),
              if (link.verificationCode.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Check this matches on both screens',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  link.verificationCode,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                link.status == DeviceLinkStatus.error
                    ? (link.error.isEmpty
                          ? 'Could not link this device'
                          : link.error)
                    : (_notes[link.status] ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: link.status == DeviceLinkStatus.error
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
              if (canRestart) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => ref
                        .read(deviceLinkControllerProvider.notifier)
                        .start(),
                    child: const Text('Show a new code'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'AbabilX never holds your message key, so it cannot hand it '
                'over for you and cannot read what you send.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
