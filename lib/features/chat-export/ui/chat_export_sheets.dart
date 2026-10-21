import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_translations.dart';
import '../export/chat_export_runner.dart';

/// Says the zip is readable by anyone who gets it, then asks to go on.
Future<bool> confirmChatExport(BuildContext context, WidgetRef ref) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => _SheetBody(
      title: t('chat_export_confirm_title'),
      body: t('chat_export_confirm_body'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(sheet, true),
          child: Text(t('chat_export_confirm_go')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(sheet, false),
          child: Text(t('cancel')),
        ),
      ],
    ),
  );
  return go == true;
}

/// Where the zip went, and Share to send it somewhere else.
Future<void> showChatExportDone(
  BuildContext context,
  WidgetRef ref,
  ChatExportResult result,
) {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final body = t('chat_export_done_body')
      .replaceAll('{chats}', '${result.chats}')
      .replaceAll('{messages}', '${result.messages}')
      .replaceAll('{files}', '${result.files}')
      .replaceAll('{path}', result.path);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => _SheetBody(
      title: t('chat_export_done_title'),
      body: body,
      actions: [
        FilledButton(
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              files: [XFile(result.path, mimeType: 'application/zip')],
            ),
          ),
          child: Text(t('chat_export_share')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(sheet),
          child: Text(t('chat_export_close')),
        ),
      ],
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          for (final a in actions) ...[a, const SizedBox(height: 6)],
        ],
      ),
    );
  }
}
