import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../ghost/protocol/ghost_item_rules.dart';
import '../ghost/widgets/ghost_labels.dart';
import '../messages/chat_icon.dart';
import '../messages/data/models/chat_models.dart';
import 'privacy_media_pager.dart';
import 'privacy_timer_picker.dart';

/// Privacy mode's send step, as Ghost Chat's send preview: after the review
/// screen, a full-screen page shows what is about to go and asks what
/// [peerName]'s phone may do with it — a view timer (photos only) and
/// whether it may be saved.
///
/// Opens on "no timer, no saving": privacy mode is on, so the quiet choice is
/// the default and loosening it is the deliberate act. Returns null if the
/// sender backed out, which keeps the attachments in the composer.
Future<GhostItemRules?> showPrivacyMediaPreview(
  BuildContext context, {
  required String peerName,
  required List<ChatAttachmentInput> attachments,
  required bool photosOnly,
}) => Navigator.of(context).push(
  MaterialPageRoute<GhostItemRules>(
    fullscreenDialog: true,
    builder: (_) => _PrivacyMediaPreview(
      peerName: peerName,
      attachments: attachments,
      photosOnly: photosOnly,
    ),
  ),
);

class _PrivacyMediaPreview extends ConsumerStatefulWidget {
  const _PrivacyMediaPreview({
    required this.peerName,
    required this.attachments,
    required this.photosOnly,
  });

  final String peerName;
  final List<ChatAttachmentInput> attachments;
  final bool photosOnly;

  @override
  ConsumerState<_PrivacyMediaPreview> createState() =>
      _PrivacyMediaPreviewState();
}

class _PrivacyMediaPreviewState extends ConsumerState<_PrivacyMediaPreview> {
  GhostItemRules _rules = GhostItemRules.none;

  Future<void> _pickTimer() async {
    final next = await showPrivacyTimerPicker(context, ref, _rules.timer);
    if (next != null) setState(() => _rules = _rules.withTimer(next));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timed = widget.photosOnly && _rules.timer.timed;
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName, maxLines: 1)),
      body: PrivacyMediaPager(attachments: widget.attachments),
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
                      ? ghostText(
                          ref,
                          'ghost_allow_save_hint',
                          name: widget.peerName,
                        )
                      : ghostText(ref, 'privacy_media_no_save_hint'),
                ),
              ),
              Row(
                children: [
                  if (widget.photosOnly)
                    ActionChip(
                      avatar: ChatIcon(
                        HugeIcons.strokeRoundedTimer02,
                        size: 18,
                        color: colors.onSurface,
                      ),
                      label: Text(ghostTimerLabel(ref, _rules.timer)),
                      onPressed: _pickTimer,
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_rules),
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
