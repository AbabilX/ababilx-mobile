import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'media_preview_actions.dart';
import 'pdf_document_source.dart';

class PdfFullscreenDialog extends StatefulWidget {
  const PdfFullscreenDialog({
    super.key,
    required this.source,
    required this.fileName,
  });

  final PdfDocumentSource source;
  final String fileName;

  @override
  State<PdfFullscreenDialog> createState() => _PdfFullscreenDialogState();
}

class _PdfFullscreenDialogState extends State<PdfFullscreenDialog> {
  PdfControllerPinch? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final controller = PdfControllerPinch(document: widget.source.open());
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load PDF');
    }
  }

  Future<void> _run(MediaPreviewAction action) {
    final local = widget.source.isLocal;
    return runMediaPreviewAction(
      context,
      action,
      localPath: local ? widget.source.value : null,
      remoteUrl: local ? null : widget.source.value,
      fileName: widget.fileName,
      contentType: 'application/pdf',
    );
  }

  Future<void> _openExternal() async {
    final ok = widget.source.isLocal
        ? (await OpenFilex.open(widget.source.value)).type == ResultType.done
        : await launchUrl(
            Uri.parse(widget.source.value),
            mode: LaunchMode.externalApplication,
          );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF externally')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      backgroundColor: colors.surface,
      // Scaffold so the save confirmation is drawn inside the viewer rather
      // than on the screen hidden behind it.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  MediaPreviewOverflow(
                    localPath: widget.source.isLocal
                        ? widget.source.value
                        : null,
                    remoteUrl: widget.source.isLocal
                        ? null
                        : widget.source.value,
                    fileName: widget.fileName,
                    contentType: 'application/pdf',
                    onDark: false,
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(child: _body()),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _openExternal,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open externally'),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => _run(MediaPreviewAction.share),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                    IconButton(
                      tooltip: 'Save',
                      onPressed: () => _run(MediaPreviewAction.save),
                      icon: const Icon(Icons.save_alt_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) return Center(child: Text(_error!));
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfViewPinch(controller: controller);
  }
}
