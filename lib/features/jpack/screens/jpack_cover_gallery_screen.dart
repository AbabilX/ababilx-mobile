import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/name_search.dart';
import '../data/jpack_covers.dart';
import '../providers/jpack_compose_provider.dart';
import '../widgets/jpack_balance_chip.dart';
import '../widgets/jpack_cover_art.dart';
import 'jpack_compose_screen.dart';

/// The chip in the chat's + panel lands here: pick a cover, then fill it in.
Future<void> openJPackFlow(
  BuildContext context, {
  required String conversationId,
  required String recipientName,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => JPackCoverGalleryScreen(
      conversationId: conversationId,
      recipientName: recipientName,
    ),
  ),
);

/// Every cover, two to a row. Opened from the chat it leads on to the compose
/// screen; opened from the compose screen ([picking]) it hands a cover back.
class JPackCoverGalleryScreen extends ConsumerWidget {
  const JPackCoverGalleryScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    this.selectedId,
    this.picking = false,
  });

  final String conversationId;
  final String recipientName;
  final String? selectedId;
  final bool picking;

  Future<void> _choose(BuildContext context, JPackCover cover) async {
    final navigator = Navigator.of(context);
    if (picking) {
      navigator.pop(cover);
      return;
    }
    final sent = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => JPackComposeScreen(
          conversationId: conversationId,
          recipientName: recipientName,
          initialCover: cover,
        ),
      ),
    );
    if (sent == true && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final query = ref.watch(jpackCoverQueryProvider(picking));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final covers = [
      for (final c in jpackCovers)
        if (matchesNameQuery(query, [t(c.nameKey), ...c.keywords])) c,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t('jpack_covers_title')),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: JPackBalanceChip(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (v) =>
                  ref.read(jpackCoverQueryProvider(picking).notifier).state = v
                      .trim(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t('jpack_search_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: covers.isEmpty
                ? Center(
                    child: Text(
                      t('jpack_no_covers'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      const pad = 16.0;
                      const gap = 12.0;
                      final tileWidth = (box.maxWidth - pad * 2 - gap) / 2;
                      final artWidth = tileWidth - 36;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(pad, 0, pad, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                          mainAxisExtent: artWidth / jpackCoverAspect + 70,
                        ),
                        itemCount: covers.length,
                        itemBuilder: (_, i) => _CoverTile(
                          cover: covers[i],
                          name: t(covers[i].nameKey),
                          artWidth: artWidth,
                          selected: covers[i].id == selectedId,
                          onTap: () => _choose(context, covers[i]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.cover,
    required this.name,
    required this.artWidth,
    required this.selected,
    required this.onTap,
  });

  final JPackCover cover;
  final String name;
  final double artWidth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Hero(
                tag: 'jpack-cover-${cover.id}',
                child: JPackCoverArt(cover: cover, width: artWidth),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
