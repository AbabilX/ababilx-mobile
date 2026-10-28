import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'composer_format.dart';

const composerFormatBoldKey = Key('composer-format-bold');
const composerFormatItalicKey = Key('composer-format-italic');
const composerFormatLinkKey = Key('composer-format-link');
const composerFormatCutKey = Key('composer-format-cut');
const composerFormatCopyKey = Key('composer-format-copy');
const composerFormatPasteKey = Key('composer-format-paste');
const composerFormatRemoveKey = Key('composer-format-remove');

/// Selection toolbar for the composer. Icons only: bold, italic, link, cut,
/// copy, paste, and delete the selection. A caret with nothing selected keeps
/// the system menu, so paste still works when there is nothing to replace.
Widget composerFormatMenu({
  required BuildContext pageContext,
  required EditableTextState editor,
  required TextEditingController controller,
}) {
  final selection = controller.selection;
  final selected =
      selection.isValid &&
      !selection.isCollapsed &&
      selection.textInside(controller.text).trim().isNotEmpty;
  if (!selected) {
    return AdaptiveTextSelectionToolbar.editableText(editableTextState: editor);
  }
  final ink = Theme.of(pageContext).colorScheme.onSurface;
  return AdaptiveTextSelectionToolbar(
    anchors: editor.contextMenuAnchors,
    children: [
      _FormatIcon(
        key: composerFormatBoldKey,
        icon: HugeIcons.strokeRoundedTextBold,
        label: 'Bold',
        color: ink,
        onPressed: () => _commit(controller, ComposerFormat.bold),
      ),
      _FormatIcon(
        key: composerFormatItalicKey,
        icon: HugeIcons.strokeRoundedTextItalic,
        label: 'Italic',
        color: ink,
        onPressed: () => _commit(controller, ComposerFormat.italic),
      ),
      _FormatIcon(
        key: composerFormatLinkKey,
        icon: HugeIcons.strokeRoundedLink01,
        label: 'Link',
        color: ink,
        onPressed: () => _askLink(pageContext, controller),
      ),
      _FormatIcon(
        key: composerFormatCutKey,
        icon: HugeIcons.strokeRoundedScissor01,
        label: 'Cut',
        color: ink,
        onPressed: () => editor.cutSelection(SelectionChangedCause.toolbar),
      ),
      _FormatIcon(
        key: composerFormatCopyKey,
        icon: HugeIcons.strokeRoundedCopy01,
        label: 'Copy',
        color: ink,
        onPressed: () => editor.copySelection(SelectionChangedCause.toolbar),
      ),
      _FormatIcon(
        key: composerFormatPasteKey,
        icon: HugeIcons.strokeRoundedClipboardPaste,
        label: 'Paste',
        color: ink,
        onPressed: () => editor.pasteText(SelectionChangedCause.toolbar),
      ),
      _FormatIcon(
        key: composerFormatRemoveKey,
        icon: HugeIcons.strokeRoundedDelete02,
        label: 'Remove',
        color: ink,
        onPressed: () => _commit(controller, ComposerFormat.remove),
      ),
    ],
  );
}

class _FormatIcon extends StatelessWidget {
  const _FormatIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: ChatIcon(icon, size: 22, color: color),
      ),
    );
  }
}

void _commit(
  TextEditingController controller,
  ComposerFormat format, {
  String? linkUrl,
  TextEditingValue? saved,
}) {
  ContextMenuController.removeAny();
  final base = saved ?? controller.value;
  final next = applyComposerFormat(base, format: format, linkUrl: linkUrl);
  if (next.text == controller.text && next.selection == controller.selection) {
    return;
  }
  controller.value = next;
}

Future<void> _askLink(
  BuildContext context,
  TextEditingController controller,
) async {
  final saved = controller.value;
  ContextMenuController.removeAny();
  final url = await askComposerLink(context);
  if (url == null || controller.text != saved.text) return;
  _commit(controller, ComposerFormat.link, linkUrl: url, saved: saved);
}

/// Asks for the address of the selected words. A sheet, so it rides the
/// keyboard the way the rest of the composer does.
Future<String?> askComposerLink(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: const ComposerLinkSheet(),
      );
    },
  );
}

class ComposerLinkSheet extends StatefulWidget {
  const ComposerLinkSheet({super.key});

  @override
  State<ComposerLinkSheet> createState() => _ComposerLinkSheetState();
}

class _ComposerLinkSheetState extends State<ComposerLinkSheet> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = normalizeComposerLinkUrl(_url.text) != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Link', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: 'https://',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: ready ? _add : null,
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _add() {
    final url = normalizeComposerLinkUrl(_url.text);
    if (url == null) return;
    Navigator.of(context).pop(url);
  }
}
