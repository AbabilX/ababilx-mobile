import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.conversationId,
    this.parentId,
    this.initialText = '',
  });

  final String conversationId;
  final String? parentId;
  final String initialText;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  late final TextEditingController _ctrl;
  final _pendingAttachments = <ChatAttachmentInput>[];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty && _pendingAttachments.isEmpty) return;
    await ref.read(chatProvider.notifier).sendMessage(
          body: body,
          attachments: List.of(_pendingAttachments),
          parentId: widget.parentId,
        );
    _ctrl.clear();
    setState(() => _pendingAttachments.clear());
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _uploadBytes(
      bytes,
      file.name,
      file.mimeType ?? 'image/jpeg',
    );
  }

  Future<void> _showAttachSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _uploadBytes(
    List<int> bytes,
    String name,
    String contentType,
  ) async {
    final notifier = ref.read(chatProvider.notifier);
    final presign = await notifier.presignAttachment(
      widget.conversationId,
      contentType: contentType,
      fileName: name,
      sizeBytes: bytes.length,
    );
    await notifier.uploadAttachmentBytes(presign, bytes, contentType);
    setState(() {
      _pendingAttachments.add(
        ChatAttachmentInput(
          fileUrl: presign.publicUrl,
          fileName: name,
          contentType: contentType,
          sizeBytes: bytes.length,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatProvider).sending;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pendingAttachments.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, i) {
                      final a = _pendingAttachments[i];
                      return Chip(
                        label: Text(a.fileName, overflow: TextOverflow.ellipsis),
                        onDeleted: () =>
                            setState(() => _pendingAttachments.removeAt(i)),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemCount: _pendingAttachments.length,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: sending
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    onPressed: sending ? null : _showAttachSheet,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
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
