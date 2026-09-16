import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/name_search.dart';
import '../data/jpack_covers.dart';
import '../providers/jpack_compose_provider.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../widgets/jpack_bottom_bar.dart';
import '../widgets/jpack_cover_art.dart';
import '../widgets/jpack_cover_tile.dart';
import '../widgets/jpack_search_field.dart';
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
class JPackCoverGalleryScreen extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<JPackCoverGalleryScreen> createState() =>
      _JPackCoverGalleryScreenState();
}

class _JPackCoverGalleryScreenState
    extends ConsumerState<JPackCoverGalleryScreen> {
  late final TextEditingController _searchCtrl = TextEditingController(
    text: ref.read(jpackCoverQueryProvider(widget.picking)),
  );

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String v) {
    ref.read(jpackCoverQueryProvider(widget.picking).notifier).state = v.trim();
    setState(() {});
  }

  Future<void> _choose(BuildContext context, JPackCover cover) async {
    final navigator = Navigator.of(context);
    if (widget.picking) {
      navigator.pop(cover);
      return;
    }
    final sent = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => JPackComposeScreen(
          conversationId: widget.conversationId,
          recipientName: widget.recipientName,
          initialCover: cover,
        ),
      ),
    );
    if (sent == true && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final query = ref.watch(jpackCoverQueryProvider(widget.picking));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final covers = [
      for (final c in jpackCovers)
        if (matchesNameQuery(query, [t(c.nameKey), ...c.keywords])) c,
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                const pad = 12.0;
                const gap = 10.0;
                final tileWidth = (box.maxWidth - pad * 2 - gap) / 2;
                final artWidth = tileWidth - 20;
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      title: Text(t('jpack_covers_title')),
                      centerTitle: true,
                      floating: true,
                      snap: true,
                    ),
                    if (covers.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            t('jpack_no_covers'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          pad,
                          4,
                          pad,
                          ShellPillMetrics.contentBottom(context),
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: gap,
                                mainAxisExtent:
                                    artWidth / jpackCoverAspect + 34,
                              ),
                          itemCount: covers.length,
                          itemBuilder: (_, i) => JPackCoverTile(
                            cover: covers[i],
                            name: t(covers[i].nameKey),
                            artWidth: artWidth,
                            selected: covers[i].id == widget.selectedId,
                            onTap: () => _choose(context, covers[i]),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: JPackBottomBar(
              child: JPackSearchField(
                controller: _searchCtrl,
                hintText: t('jpack_search_hint'),
                onChanged: _setQuery,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
