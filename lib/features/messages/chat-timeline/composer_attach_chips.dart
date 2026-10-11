import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_icon.dart';
import 'composer_attach_order.dart';

/// What one chip shows and does.
class AttachChipSpec {
  const AttachChipSpec({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;
}

/// The row of destinations under the rail. Tap opens one; hold and drag
/// arranges them, and the order is kept on this device.
class ComposerAttachChips extends ConsumerStatefulWidget {
  const ComposerAttachChips({super.key, required this.chips});

  /// Only the destinations this chat offers.
  final Map<AttachDestination, AttachChipSpec> chips;

  @override
  ConsumerState<ComposerAttachChips> createState() =>
      _ComposerAttachChipsState();
}

class _ComposerAttachChipsState extends ConsumerState<ComposerAttachChips> {
  @override
  void dispose() {
    // The panel can close under a held chip; the blur must not outlive it.
    attachReordering.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chips = widget.chips;
    final ordered = applyAttachOrder(
      chips.keys.toList(),
      ref.watch(attachOrderProvider),
    );
    return SizedBox(
      height: 94,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: ordered.length,
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        onReorderStart: (_) {
          HapticFeedback.selectionClick();
          attachReordering.value = true;
        },
        onReorderEnd: (_) => attachReordering.value = false,
        onReorderItem: (from, to) {
          if (from == to) return;
          final next = [...ordered];
          next.insert(to, next.removeAt(from));
          ref.read(attachOrderProvider.notifier).save(next);
        },
        itemBuilder: (context, i) {
          final spec = chips[ordered[i]]!;
          return ReorderableDelayedDragStartListener(
            key: ValueKey(ordered[i]),
            index: i,
            child: AttachChip(
              label: spec.label,
              icon: spec.icon,
              onTap: spec.onTap,
            ),
          );
        },
      ),
    );
  }
}

/// One rounded-square destination under the rail.
class AttachChip extends StatelessWidget {
  const AttachChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: ChatIcon(icon, size: 26, color: colors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
