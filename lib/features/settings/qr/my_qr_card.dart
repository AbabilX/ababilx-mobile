import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The card the code is drawn on.
///
/// The QR itself is always black on white, whatever the app theme is doing.
/// A scanner reads contrast, and a dark-mode code drawn in the accent colour
/// is the classic reason a camera stares at a screen and finds nothing.
class MyQrCard extends StatelessWidget {
  const MyQrCard({
    super.key,
    required this.payload,
    required this.name,
    required this.username,
  });

  final String payload;
  final String name;
  final String username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: payload,
              size: 220,
              backgroundColor: Colors.white,
              // Medium recovery: the code holds a short handle, so the extra
              // redundancy costs nothing visible and survives a fingerprint on
              // the screen.
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 20),
          if (name.isNotEmpty)
            Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            '@$username',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
