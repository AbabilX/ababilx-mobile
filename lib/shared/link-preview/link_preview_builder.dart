import 'package:flutter/material.dart';

import 'link_preview_cache.dart';
import 'link_preview_data.dart';
import 'link_preview_loader.dart';

/// Holds one unfurl for as long as the widget lives.
///
/// Stateful on purpose: calling [loadLinkPreview] from `build` would start a
/// fresh future on every rebuild, and a `FutureBuilder` handed a new future
/// reports null again for a frame — so a card would blink out whenever the
/// bubble rebuilt for something unrelated, a reaction or a delivery tick.
class LinkPreviewBuilder extends StatefulWidget {
  const LinkPreviewBuilder({
    super.key,
    required this.url,
    required this.builder,
  });

  final String url;

  /// Called with null until there is something to draw, and with null forever
  /// if there never was — a link with no card is still a link.
  final Widget Function(BuildContext context, LinkPreviewData? preview) builder;

  @override
  State<LinkPreviewBuilder> createState() => _LinkPreviewBuilderState();
}

class _LinkPreviewBuilderState extends State<LinkPreviewBuilder> {
  LinkPreviewData? _preview;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LinkPreviewBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _preview = null;
      _start();
    }
  }

  void _start() {
    // A cached preview is drawn on the first frame rather than one frame late,
    // so scrolling back over a chat does not re-flash every card.
    _preview = LinkPreviewCache.instance.peek(widget.url);
    final url = widget.url;
    loadLinkPreview(url).then((preview) {
      if (!mounted || url != widget.url) return;
      setState(() => _preview = preview);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _preview);
}
