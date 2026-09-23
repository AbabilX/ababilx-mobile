import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../ghost/protocol/ghost_item_rules.dart';
import '../ghost/widgets/ghost_labels.dart';
import '../messages/chat_icon.dart';

/// Privacy mode's send step: after the preview, before anything is sent, the
/// sender decides what [peerName]'s phone may do with these attachments —
/// Ghost Chat's two controls, carried into an ordinary DM.
///
/// Opens on "no timer, no saving": privacy mode is on, so the quiet choice is
/// the default and loosening it is the deliberate act. The timer is offered
/// only when every attachment is a photo. Returns null if the sender backed
/// out, which keeps the attachments in the composer.
Future<GhostItemRules?> showPrivacyMediaSheet(
  BuildContext context, {
  required String peerName,
  required bool photosOnly,
}) => showModalBottomSheet<GhostItemRules>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) =>
      _PrivacyMediaSheet(peerName: peerName, photosOnly: photosOnly),
);

class _PrivacyMediaSheet extends ConsumerStatefulWidget {
  const _PrivacyMediaSheet({required this.peerName, required this.photosOnly});

  final String peerName;
  final bool photosOnly;

  @override
  ConsumerState<_PrivacyMediaSheet> createState() => _PrivacyMediaSheetState();
}

class _PrivacyMediaSheetState extends ConsumerState<_PrivacyMediaSheet> {
  GhostItemRules _rules = GhostItemRules.none;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timed = _rules.timer.timed;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.photosOnly) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  ghostText(ref, 'ghost_timer_title'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final timer in GhostViewTimer.values)
                    ChoiceChip(
                      avatar: timer.timed
                          ? ChatIcon(
                              HugeIcons.strokeRoundedTimer02,
                              size: 16,
                              color: timer == _rules.timer
                                  ? colors.onSecondaryContainer
                                  : null,
                            )
                          : null,
                      label: Text(ghostTimerLabel(ref, timer)),
                      selected: timer == _rules.timer,
                      onSelected: (_) =>
                          setState(() => _rules = _rules.withTimer(timer)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
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
                    ? ghostText(
                        ref,
                        'ghost_allow_save_hint',
                        name: widget.peerName,
                      )
                    : ghostText(ref, 'privacy_media_no_save_hint'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_rules),
                icon: const ChatIcon(
                  HugeIcons.strokeRoundedSent,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(ghostText(ref, 'ghost_send')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
