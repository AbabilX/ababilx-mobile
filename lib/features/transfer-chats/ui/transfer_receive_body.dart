import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../wire/transfer_chats_wire.dart';
import 'transfer_chats_copy.dart';

/// What the new phone shows at each step.
class TransferReceiveBody extends ConsumerWidget {
  const TransferReceiveBody({
    super.key,
    required this.payload,
    required this.status,
    required this.onRetry,
    required this.onDone,
  });

  /// Null while starting, empty when there is no Wi-Fi.
  final String? payload;
  final TransferStatus status;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => transferText(ref, key);
    final code = payload;
    switch (status.step) {
      case TransferStep.waiting:
        if (code == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (code.isEmpty) {
          return TransferMessage(text: t('receive_no_wifi'), onRetry: onRetry);
        }
        return _Code(payload: code);
      case TransferStep.receiving:
        return TransferProgress(
          text: '${t('receiving')}  ${formatTransferBytes(status.bytes)}',
        );
      case TransferStep.importing:
        return TransferProgress(text: '${t('importing')}  ${status.messages}');
      case TransferStep.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('done_body')
                  .replaceAll('{messages}', '${status.messages}')
                  .replaceAll('{files}', '${status.files}'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onDone, child: Text(t('continue'))),
          ],
        );
      case TransferStep.failed:
        return TransferMessage(
          text: t('error_${status.error.isEmpty ? 'failed' : status.error}'),
          onRetry: onRetry,
        );
    }
  }
}

class _Code extends ConsumerWidget {
  const _Code({required this.payload});
  final String payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => transferText(ref, key);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: QrImageView(
            data: payload,
            size: 240,
            backgroundColor: Colors.white,
            // Long code (a key, a secret, an address): low recovery keeps the
            // modules big enough for an older camera at arm's length.
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          ),
        ),
        const SizedBox(height: 20),
        Text(t('receive_steps'), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          '${t('receive_same_wifi')}\n${t('encrypted_note')}',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}

class TransferProgress extends StatelessWidget {
  const TransferProgress({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const LinearProgressIndicator(),
      const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center),
    ],
  );
}

class TransferMessage extends ConsumerWidget {
  const TransferMessage({super.key, required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(text, textAlign: TextAlign.center),
      if (onRetry != null) ...[
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onRetry,
          child: Text(transferText(ref, 'receive_retry')),
        ),
      ],
    ],
  );
}

String formatTransferBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
