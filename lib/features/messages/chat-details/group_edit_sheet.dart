import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/friendly_error.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_edit_images.dart';
import 'group_permissions.dart';

/// The pencil in the details app bar: banner, photo, name and description in
/// one sheet, saved through the group info endpoint.
///
/// Every group gets all of it. A workspace channel used to get the name field
/// alone, because it took its identity from the team; since the server's
/// migration 0145 a converted channel is an ordinary group and its identity is
/// its own.
Future<bool> showGroupEditSheet(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // The keyboard and the system navigation bar never both apply: while
        // the keyboard is up the gesture/nav inset collapses to nothing. Take
        // whichever is actually there, or Save ends up under one of them.
        bottom:
            (MediaQuery.viewInsetsOf(sheet).bottom >
                    MediaQuery.viewPaddingOf(sheet).bottom
                ? MediaQuery.viewInsetsOf(sheet).bottom
                : MediaQuery.viewPaddingOf(sheet).bottom) +
            24,
      ),
      child: _EditForm(
        // The pictures save themselves the moment they are cropped, so they
        // are handed the conversation rather than the form's draft state:
        // there is nothing about them for Save to commit.
        //
        // The permission is re-checked here rather than trusted from the one
        // caller: a member of an admins-only group would otherwise pick and
        // crop a photo and only then be told no, by a 403 from the server.
        //
        // A feed takes a third path. Its picture belongs to the webhook rather
        // than to the conversation, and nobody may upload an attachment to a
        // conversation nobody may post into — so the group flow's presign is a
        // 403 there no matter who asks.
        images: groupEditPictures(conversation, GroupPermissions(conversation)),
        initialName: conversation.name ?? '',
        initialDescription: conversation.description ?? '',
        onSave: (name, description) async {
          if (name.isEmpty) return;
          await ref
              .read(chatProvider.notifier)
              .updateGroupInfo(
                conversation.id,
                name: name,
                description: description,
              );
          if (sheet.mounted) Navigator.pop(sheet, true);
        },
      ),
    ),
  );

  return saved ?? false;
}

class _EditForm extends StatefulWidget {
  const _EditForm({
    required this.images,
    required this.initialName,
    required this.initialDescription,
    required this.onSave,
  });

  final Widget? images;
  final String initialName;
  final String initialDescription;
  final Future<void> Function(String name, String description) onSave;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  // The form owns its controllers. Disposing them from the caller as soon as
  // showModalBottomSheet's future completed tore them down while the sheet's
  // close animation was still rebuilding the fields — "A TextEditingController
  // was used after being disposed", and a red screen behind the sheet.
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _descCtrl = TextEditingController(text: widget.initialDescription);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Give the group a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_nameCtrl.text.trim(), _descCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _saveErrorCopy(e);
        });
      }
    }
  }

  /// Never Dio's paragraph. A 403 here means the roster changed under the
  /// sheet — demoted, or the switch flipped — so say that, not "bad syntax".
  static String _saveErrorCopy(Object e) {
    if (serverErrorCode(e) == 'not_conversation_manager') {
      return 'Only an admin can change this group.';
    }
    return serverErrorMessage(e) ?? friendlyErrorMessage(e);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Group info',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      if (widget.images != null) ...[
        widget.images!,
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _nameCtrl,
        // The pictures are above the fields, so opening the keyboard on top of
        // them would hide the thing the sheet just offered.
        autofocus: widget.images == null,
        decoration: const InputDecoration(labelText: 'Group name'),
        textCapitalization: TextCapitalization.sentences,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _descCtrl,
        maxLines: 3,
        minLines: 1,
        decoration: const InputDecoration(labelText: 'Description'),
        textCapitalization: TextCapitalization.sentences,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
      ),
    ],
  );
}
