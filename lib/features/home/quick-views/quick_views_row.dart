import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat-lock/providers/chat_locks_provider.dart';
import '../data/home_drafts.dart';
import 'quick_view_card.dart';
import 'quick_view_prefs.dart';
import 'quick_view_summary.dart';
import 'quick_views.dart';

/// True while a Home card is held for rearranging. Home blurs everything
/// else on it (`FilterReorderBlur(on:)`), the chat-list pills' rule.
final ValueNotifier<bool> quickViewReordering = ValueNotifier(false);

/// The cards along the top of Home. Hold one and drag to arrange them — the
/// same gesture as the chat list's pills and the bottom bar's tabs; a quick
/// tap still opens the card. No settings sheet: the row is its own editor.
class QuickViewsRow extends ConsumerWidget {
  const QuickViewsRow({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String route) async {
    await context.push(route);
    // A draft may have been written or sent on the way.
    ref.invalidate(homeDraftsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocked = ref.watch(chatLocksProvider.select((m) => m.isNotEmpty));
    final views = visibleQuickViews(
      ref.watch(quickViewPrefsProvider).arranged,
      hasLocked: hasLocked,
    );
    return SizedBox(
      height: QuickViewCard.heightFor(context) + 8,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        itemCount: views.length,
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        onReorderStart: (_) {
          HapticFeedback.mediumImpact();
          quickViewReordering.value = true;
        },
        onReorderEnd: (_) => quickViewReordering.value = false,
        onReorderItem: (from, to) => ref
            .read(quickViewPrefsProvider.notifier)
            .move(from, to, visible: views),
        itemBuilder: (context, i) {
          final view = views[i];
          final QuickViewSpec spec = quickViewSpecs[view]!;
          final summary = summarizeQuickView(context, ref, view);
          return ReorderableDelayedDragStartListener(
            key: ValueKey(view),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: QuickViewCard(
                icon: spec.icon,
                title: homeText(context, ref, spec.labelKey),
                subtitle: summary.subtitle,
                attention: summary.attention,
                alert: summary.alert,
                onTap: () => _open(context, ref, spec.route),
              ),
            ),
          );
        },
      ),
    );
  }
}
