import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../protocol/ghost_item_rules.dart';
import '../providers/ghost_provider.dart';
import '../providers/ghost_save.dart';
import '../providers/ghost_state.dart';
import '../widgets/ghost_labels.dart';
import 'ghost_viewer_guard.dart';

Future<void> showGhostPhoto(BuildContext context, GhostItem item) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GhostPhotoViewer(id: item.id),
      ),
    );

/// A Ghost photo, full screen, from memory.
///
/// For a timed photo on the receiving phone this IS the viewing: the countdown
/// starts on open, and closing — by the timer, back, or the chat ending — is
/// what expires it on both phones ([GhostNotifier.viewed], from dispose, so
/// every way out counts). The countdown is a wall-clock [Timer], not the
/// animation: animations stop while the app is in the background, and a photo
/// must not wait out its timer behind the home screen.
class GhostPhotoViewer extends ConsumerStatefulWidget {
  const GhostPhotoViewer({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GhostPhotoViewer> createState() => _GhostPhotoViewerState();
}

class _GhostPhotoViewerState extends ConsumerState<GhostPhotoViewer>
    with SingleTickerProviderStateMixin {
  // Read in initState: dispose, where it is used, may not touch ref.
  late final GhostNotifier _notifier;
  AnimationController? _ring;
  Timer? _deadline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(ghostProvider.notifier);
    final item = _find();
    final duration = item?.fromMe == false && item!.timed
        ? item.rules.timer.duration
        : null;
    if (duration != null) {
      _ring = AnimationController(vsync: this, duration: duration)..forward();
      _deadline = Timer(duration, () {
        if (mounted) closeGhostViewer(context);
      });
    }
  }

  GhostItem? _find() {
    for (final item in ref.read(ghostProvider).items) {
      if (item.id == widget.id) return item;
    }
    return null;
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _ring?.dispose();
    // Not inline: dispose runs while the tree is locked, and expiring changes
    // provider state that other widgets are listening to.
    final notifier = _notifier, id = widget.id;
    Future.microtask(() => notifier.viewed(id));
    super.dispose();
  }

  Future<void> _save(GhostItem item) async {
    setState(() => _saving = true);
    final ok = await saveGhostItem(item);
    if (!mounted) return;
    setState(() => _saving = false);
    showAppToast(
      context,
      ghostText(ref, ok ? 'ghost_saved' : 'ghost_save_failed'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = watchGhostViewerItem(context, ref, widget.id);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const ChatIcon(
            HugeIcons.strokeRoundedCancel01,
            color: Colors.white,
          ),
        ),
        actions: [
          if (item != null) ..._actions(item),
          const SizedBox(width: 8),
        ],
      ),
      body: item == null
          ? const SizedBox.expand()
          : InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.memory(item.bytes!, gaplessPlayback: true),
              ),
            ),
    );
  }

  List<Widget> _actions(GhostItem item) {
    final ring = _ring;
    if (ring != null) {
      return [_Countdown(ring: ring, total: item.rules.timer.duration!)];
    }
    if (!item.fromMe && item.rules.timer == GhostViewTimer.once) {
      return [
        Center(
          child: Text(
            ghostTimerLabel(ref, GhostViewTimer.once),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ];
    }
    if (!item.fromMe && item.rules.allowSave) {
      return [
        IconButton(
          onPressed: _saving ? null : () => _save(item),
          tooltip: ghostText(ref, 'ghost_save'),
          icon: const ChatIcon(
            HugeIcons.strokeRoundedDownload04,
            color: Colors.white,
          ),
        ),
      ];
    }
    return const [];
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.ring, required this.total});

  final AnimationController ring;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ring,
      builder: (context, _) {
        final left = (total.inSeconds * (1 - ring.value)).ceil();
        return SizedBox.square(
          dimension: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1 - ring.value,
                strokeWidth: 2.5,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
              Text(
                '$left',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
