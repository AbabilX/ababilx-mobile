import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens the store page for this app. On Android a Play link goes to the Play
/// app directly (`market://`), falling back to the web link. Returns false
/// when nothing could be opened.
Future<bool> openAppStore(String storeUrl) async {
  final web = Uri.tryParse(storeUrl);
  if (web == null || !web.hasScheme) return false;
  final id = web.queryParameters['id'];
  if (Platform.isAndroid && web.host == 'play.google.com' && id != null) {
    try {
      final market = Uri(
        scheme: 'market',
        host: 'details',
        queryParameters: {'id': id},
      );
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}
  }
  try {
    return await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
