import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ghost_provider.dart';
import '../providers/ghost_state.dart';

/// The item a full-screen Ghost viewer shows, or null once it must close:
/// the chat burned or ended, or the photo's time ran out elsewhere.
///
/// Every viewer pops itself on null. GhostSync owns the Ghost routes and only
/// moves them on `idle`, which comes after the ended screen — so a viewer left
/// open over a burned chat would otherwise sit there showing freed bytes.
GhostItem? watchGhostViewerItem(
  BuildContext context,
  WidgetRef ref,
  String id,
) {
  final state = ref.watch(ghostProvider);
  GhostItem? item;
  if (state.inSession) {
    for (final i in state.items) {
      if (i.id == id) item = i;
    }
  }
  if (item == null || item.expired || item.bytes == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) closeGhostViewer(context);
    });
    return null;
  }
  return item;
}

/// Removes exactly the viewer [context] belongs to, and only once.
///
/// Never `maybePop`: while this route animates out it keeps rebuilding, and a
/// second pop would land on the Ghost chat screen underneath — whose back
/// handler closes an ended chat and skips the "burned" screen entirely.
void closeGhostViewer(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}
