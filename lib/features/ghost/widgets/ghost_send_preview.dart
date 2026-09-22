import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../protocol/ghost_item_rules.dart';
import '../providers/ghost_provider.dart';
import 'ghost_labels.dart';
import 'ghost_pick.dart';

/// Asks what the other phone may do with [picked] before it is sent: a view
/// timer (photos only) and whether it may be saved. Returns the rules, or null
/// if the sender backed out. Opens on the previous choice of this session.
Future<GhostItemRules?> showGhostSendPreview(
  BuildContext context,
  GhostPicked picked,
) => Navigator.of(context).push(
  MaterialPageRoute<GhostItemRules>(
    fullscreenDialog: true,
    builder: (_) => _GhostSendPreview(picked: picked),
  ),
);

class _GhostSendPreview extends ConsumerStatefulWidget {
  const _GhostSendPreview({required this.picked});

  final GhostPicked picked;

  @override
  ConsumerState<_GhostSendPreview> createState() => _GhostSendPreviewState();
}

class _GhostSendPreviewState extends ConsumerState<_GhostSendPreview> {
  /// A file never carries a timer, so it starts from the save choice alone.
  late GhostItemRules _rules = _isPhoto
      ? ref.read(ghostProvider).lastRules
      : GhostItemRules(allowSave: ref.read(ghostProvider).lastRules.allowSave);

  bool get _isPhoto => widget.picked.mime.startsWith('image/');

  Future<void> _pickTimer() async {
    final next = await showModalBottomSheet<GhostViewTimer>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(ghostText(ref, 'ghost_timer_title'))),
            for (final timer in GhostViewTimer.values)
              ListTile(
                leading: ChatIcon(
                  timer.timed
                      ? HugeIcons.strokeRoundedTimer02
                      : HugeIcons.strokeRoundedView,
                ),
                title: Text(ghostTimerLabel(ref, timer)),
                trailing: timer == _rules.timer
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheet).pop(timer),
              ),
          ],
        ),
      ),
    );
    if (next != null) setState(() => _rules = _rules.withTimer(next));
  }

  void _send() {
    final notifier = ref.read(ghostProvider.notifier);
    // Sending a file must not forget the photo timer the sender last chose.
    notifier.rememberRules(
      _isPhoto
          ? _rules
          : ref.read(ghostProvider).lastRules.withSave(_rules.allowSave),
    );
    Navigator.of(context).pop(_rules);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timed = _isPhoto && _rules.timer.timed;
    final peer = ref.watch(ghostProvider.select((s) => s.peerName));
    if (!ref.watch(ghostProvider.select((s) => s.inSession))) {
      // Burned, left or dropped while choosing: nothing to send it to.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = ModalRoute.of(context);
        if (mounted && route != null && route.isCurrent) {
          Navigator.of(context).pop();
        }
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.picked.name, maxLines: 1)),
      body: Center(
        child: _isPhoto
            ? Image.memory(
                widget.picked.bytes,
                fit: BoxFit.contain,
                cacheWidth:
                    (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
              )
            : const ChatIcon(HugeIcons.strokeRoundedFile01, size: 72),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: _rules.allowSave,
                onChanged: timed
                    ? null
                    : (on) => setState(() => _rules = _rules.withSave(on)),
                title: Text(ghostText(ref, 'ghost_allow_save')),
                subtitle: Text(
                  timed
                      ? ghostText(ref, 'ghost_timer_no_save')
                      : _rules.allowSave
                      ? ghostText(ref, 'ghost_allow_save_hint', name: peer)
                      : ghostText(ref, 'ghost_no_save_hint'),
                ),
              ),
              Row(
                children: [
                  if (_isPhoto)
                    ActionChip(
                      avatar: ChatIcon(
                        HugeIcons.strokeRoundedTimer02,
                        size: 18,
                        color: timed ? colors.primary : null,
                      ),
                      label: Text(ghostTimerLabel(ref, _rules.timer)),
                      onPressed: _pickTimer,
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _send,
                    icon: const ChatIcon(
                      HugeIcons.strokeRoundedSent,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(ghostText(ref, 'ghost_send')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
