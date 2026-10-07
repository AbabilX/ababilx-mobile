import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/media_save_lock.dart';
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
  bool noSave = false,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => SnippetViewerScreen(
      fileName: fileName,
      localPath: localPath,
      detail: detail,
      noSave: noSave,
    ),
  ),
);

/// The whole snippet on its own page: markdown formatted, with a switch to
/// its source; plain text as written.
class SnippetViewerScreen extends ConsumerStatefulWidget {
  const SnippetViewerScreen({
    super.key,
    required this.fileName,
    required this.localPath,
    this.detail,
    this.noSave = false,
  });

  final String fileName;
  final String localPath;
  final String? detail;

  /// The file may not leave the app: no Copy and no text selection here.
  final bool noSave;

  @override
  ConsumerState<SnippetViewerScreen> createState() => _SnippetViewerState();
}

class _SnippetViewerState extends ConsumerState<SnippetViewerScreen> {
  // Held only for a file small enough to draw formatted.
  String? _text;
  List<String>? _lines;
  bool _failed = false;
  bool get _canFormat => _text != null;
  bool _formatted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final markdown = snippetKindOf(widget.fileName) == SnippetKind.markdown;
      final file = await readSnippetFile(
        widget.localPath,
        keepTextUpToBytes: markdown ? maxRenderedMarkdownBytes : 0,
      );
      if (!mounted) return;
      setState(() {
        _text = file.text;
        _lines = file.lines;
        _formatted = file.text != null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _copy(SnippetStrings s) async {
    try {
      final text = _text ?? await readSnippetText(widget.localPath);
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) showAppToast(context, s.copied);
    } catch (_) {
      if (mounted) showAppToast(context, s.unreadable, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SnippetStrings.of(ref.watch(appLanguageProvider));
    final colors = Theme.of(context).colorScheme;
    final detail = widget.detail;
    // A private group holds the lock for as long as its chat is open.
    final locked = widget.noSave || MediaSaveLock.held;
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
          if (!locked)
            IconButton(
              tooltip: s.copy,
              onPressed: _lines == null ? null : () => _copy(s),
              icon: ChatIcon(
                HugeIcons.strokeRoundedCopy01,
                color: colors.onSurface,
              ),
            ),
        ],
      ),
      body: SafeArea(child: _body(context, s, colors, selectable: !locked)),
    );
  }

  Widget _body(
    BuildContext context,
    SnippetStrings s,
    ColorScheme colors, {
    required bool selectable,
  }) {
    Widget select(Widget child) =>
        selectable ? SelectionArea(child: child) : child;
    if (_failed) return Center(child: Text(s.unreadable));
    final lines = _lines;
    if (lines == null) return const Center(child: CircularProgressIndicator());
    final base = Theme.of(
      context,
    ).textTheme.bodyLarge!.copyWith(color: colors.onSurface, height: 1.45);
    if (_formatted && _text != null) {
      return select(
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: MessageMarkdown(source: _text!, style: base),
        ),
      );
    }
    final mono = base.copyWith(fontFamily: 'monospace', fontSize: 13.5);
    final tooLargeNote =
        snippetKindOf(widget.fileName) == SnippetKind.markdown && !_canFormat;
    // Built lazily, row by row: one Text of ten megabytes is laid out whole.
    return select(
      ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: lines.length + (tooLargeNote ? 1 : 0),
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
          final line = lines[index - (tooLargeNote ? 1 : 0)];
          return Text(line.isEmpty ? ' ' : line, style: mono);
        },
      ),
    );
  }
}
