part of 'tiptap_blocks.dart';

/// Lists, quotes and code blocks — the container blocks, split out to keep
/// each renderer file small.
extension TiptapContainerBlocks on TiptapBlocks {
  Widget _list(Map<String, dynamic> node, {required bool ordered}) {
    final items = _listItems(node);
    final start = (node['attrs'] as Map?)?['start'] as int? ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          _listRow(bullet: ordered ? '${start + i}.' : '•', child: items[i]),
      ],
    );
  }

  Widget _taskList(Map<String, dynamic> node) {
    final content = node['content'];
    if (content is! List) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in content.whereType<Map>())
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  (item['attrs'] as Map?)?['checked'] == true
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(child: _itemBody(Map<String, dynamic>.from(item))),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _listItems(Map<String, dynamic> node) {
    final content = node['content'];
    if (content is! List) return const [];
    return content
        .whereType<Map>()
        .map((n) => _itemBody(Map<String, dynamic>.from(n)))
        .toList();
  }

  Widget _itemBody(Map<String, dynamic> node) {
    final inner = node['content'];
    if (inner is! List) return const SizedBox.shrink();
    return column(
      inner
          .whereType<Map>()
          .map((n) => buildBlock(Map<String, dynamic>.from(n)))
          .whereType<Widget>()
          .toList(),
    );
  }

  Widget _listRow({required String bullet, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(bullet, style: baseStyle.copyWith(height: 1.5)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _blockquote(Map<String, dynamic> node) {
    final colors = Theme.of(context).colorScheme;
    final inner = node['content'];
    final children = <Widget>[];
    if (inner is List) {
      for (final child in inner.whereType<Map>()) {
        final built = buildBlock(Map<String, dynamic>.from(child));
        if (built != null) children.add(built);
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colors.primary.withValues(alpha: 0.55),
            width: 3,
          ),
        ),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: column(children),
    );
  }

  Widget _codeBlock(Map<String, dynamic> node) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          inline.plainOf(node['content']),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 14) - 1,
          ),
        ),
      ),
    );
  }
}
