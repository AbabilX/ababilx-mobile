import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/localization/app_translations.dart';

/// The camera, inside the sheet. The first code read closes the sheet with
/// it; what the code means is decided afterwards, by the scanner flow.
class AddFriendsScan extends ConsumerStatefulWidget {
  const AddFriendsScan({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  @override
  ConsumerState<AddFriendsScan> createState() => _AddFriendsScanState();
}

class _AddFriendsScanState extends ConsumerState<AddFriendsScan> {
  final _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final side = (box.maxWidth - 48).clamp(200.0, 360.0);
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox.square(
                dimension: side,
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code == null || _done) return;
                    _done = true;
                    widget.onCode(code);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                AppTranslations.translate(
                  context,
                  ref,
                  'add_friends_scan_hint',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
  }
}
