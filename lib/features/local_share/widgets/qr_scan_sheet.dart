import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Fullscreen-ish bottom sheet that scans a QR code and returns its raw
/// string content, or `null` if dismissed without a scan.
///
/// [title] and [hint] say what to point the camera at; without them the
/// sheet is the camera alone (the general scanner, which reads every code).
class QrScanSheet {
  QrScanSheet._();

  static Future<String?> show(
    BuildContext context, {
    String? title,
    String? hint,
  }) async {
    final controller = MobileScannerController();
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final camera = MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null) Navigator.of(sheetContext).pop(code);
          },
        );
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: title == null && hint == null
              ? camera
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(title, style: theme.textTheme.titleMedium),
                          if (hint != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              hint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(child: camera),
                  ],
                ),
        );
      },
    );
    controller.dispose();
    return scanned;
  }
}
