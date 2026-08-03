import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Fullscreen-ish bottom sheet that scans a QR code and returns its raw
/// string content, or `null` if dismissed without a scan.
class QrScanSheet {
  QrScanSheet._();

  static Future<String?> show(BuildContext context) async {
    final controller = MobileScannerController();
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        child: MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null) Navigator.of(sheetContext).pop(code);
          },
        ),
      ),
    );
    controller.dispose();
    return scanned;
  }
}
