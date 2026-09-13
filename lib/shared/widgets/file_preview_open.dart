import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hand the bytes to another app. Chat always has a local path; wall / CRM
/// still stream a URL.
Future<void> openPreviewExternally(
  BuildContext context, {
  String? localPath,
  String? remoteUrl,
  String contentType = '',
}) async {
  final path = localPath?.trim() ?? '';
  final url = remoteUrl?.trim() ?? '';
  var ok = false;
  if (path.isNotEmpty) {
    final result = await OpenFilex.open(
      path,
      type: contentType.isEmpty ? null : contentType,
    );
    ok = result.type == ResultType.done;
  } else if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this file')));
  }
}
