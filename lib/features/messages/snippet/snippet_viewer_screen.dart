import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat_icon.dart';
import '../markdown/message_markdown.dart';
import 'snippet_file_reader.dart';
import 'snippet_format.dart';
import 'snippet_strings.dart';

Future<void> openSnippetViewer(
  BuildContext context, {
  required String fileName,
  required String localPath,
  String? detail,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => SnippetViewerScreen(
      fileName: fileName,
      localPath: localPath,
      detail: detail,
    ),
  ),
);

/// The whole snippet on its own page. Markdown is drawn formatted, with a
/// switch to its source; plain text is drawn as written.
class SnippetViewerScreen extends ConsumerStatefulWidget {
  const SnippetViewerScreen({
    super.key,
    required this.fileName,
    required this.localPath,
    this.detail,
  });

  final String fileName;
  final String localPath;
  final String? detail;

  @override
  ConsumerState<SnippetViewerScreen> createState() => _SnippetViewerState();
}

class _SnippetViewerState extends ConsumerState<SnippetViewerScreen> {
  String? _text;
  List<String> _lines = const [];
  bool _failed = false;
  bool _canFormat = false;
  bool _formatted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await readSnippetFile(widget.localPath);
      if (!mounted) return;
      final markdown = snippetKindOf(widget.fileName) == SnippetKind.markdown;
      setState(() {
        _text = file.text;
        _lines = file.lines;
        _canFormat = markdown && file.sizeBytes <= maxRenderedMarkdownBytes;
        _formatted = _canFormat;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _copy(SnippetStrings s) async {
    final text = _text;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showAppToast(context, s.copied);
  }

  @override
  Widget build(BuildContext context) {
    final s = SnippetStrings.of(ref.watch(appLanguageProvider));
    final colors = Theme.of(context).colorScheme;
    final detail = widget.detail;
    return Scaffold(
      appBar: AppBar(
        leading: AppBarBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (detail != null && detail.isNotEmpty)
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (_canFormat)
            IconButton(
              tooltip: _formatted ? s.showSource : s.showFormatted,
              onPressed: () => setState(() => _formatted = !_formatted),
              icon: ChatIcon(
                _formatted
                    ? HugeIcons.strokeRoundedSourceCode
                    : HugeIcons.strokeRoundedTextFont,
                color: colors.onSurface,
              ),
            ),
          IconButton(
            tooltip: s.copy,
            onPressed: _text == null ? null : () => _copy(s),
            icon: ChatIcon(
              HugeIcons.strokeRoundedCopy01,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
      body: SafeArea(child: _body(context, s, colors)),
    );
  }

  Widget _body(BuildContext context, SnippetStrings s, ColorScheme colors) {
    if (_failed) return Center(child: Text(s.unreadable));
    final text = _text;
    if (text == null) return const Center(child: CircularProgressIndicator());
    final base = Theme.of(
      context,
    ).textTheme.bodyLarge!.copyWith(color: colors.onSurface, height: 1.45);
    if (_formatted) {
      return SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: MessageMarkdown(source: text, style: base),
        ),
      );
    }
    final mono = base.copyWith(fontFamily: 'monospace', fontSize: 13.5);
    final tooLargeNote =
        snippetKindOf(widget.fileName) == SnippetKind.markdown && !_canFormat;
    // Line by line and built lazily: one Text holding ten megabytes is laid
    // out whole before the first frame.
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _lines.length + (tooLargeNote ? 1 : 0),
        itemBuilder: (context, index) {
          if (tooLargeNote && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                s.sourceOnly,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          }
          final line = _lines[index - (tooLargeNote ? 1 : 0)];
          return Text(line.isEmpty ? ' ' : line, style: mono);
        },
      ),
    );
  }
}
