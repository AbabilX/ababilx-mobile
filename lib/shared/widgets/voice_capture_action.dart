import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/messages/chat-timeline/voice_message_recorder.dart';

class VoiceCaptureAction extends StatefulWidget {
  const VoiceCaptureAction({
    super.key,
    required this.onRecorded,
    this.enabled = true,
    this.tooltip = 'Hold to record',
  });

  final Future<void> Function(RecordedVoiceMessage recording) onRecorded;
  final bool enabled;
  final String tooltip;

  @override
  State<VoiceCaptureAction> createState() => _VoiceCaptureActionState();
}

class _VoiceCaptureActionState extends State<VoiceCaptureAction> {
  final _recorder = VoiceMessageRecorder();
  var _preparing = false;
  var _recording = false;
  var _finishing = false;
  var _releaseRequested = false;

  @override
  void dispose() {
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    if (!widget.enabled || _preparing || _recording || _finishing) return;
    setState(() {
      _preparing = true;
      _releaseRequested = false;
    });
    try {
      await _recorder.start();
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _preparing = false;
        _recording = true;
      });
      if (_releaseRequested) await _finish();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _recording = false;
      });
      _show('Microphone permission is required to record.');
    }
  }

  void _release() {
    if (_preparing) {
      _releaseRequested = true;
      return;
    }
    if (_recording) unawaited(_finish());
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    RecordedVoiceMessage? recording;
    try {
      recording = await _recorder.stop();
      if (recording == null ||
          recording.sizeBytes == 0 ||
          recording.duration < const Duration(milliseconds: 700)) {
        if (recording != null) await _recorder.delete(recording);
        _show('Hold a little longer to record.');
        return;
      }
      if (mounted) {
        setState(() {
          _preparing = false;
          _recording = false;
        });
      }
      await widget.onRecorded(recording);
    } catch (_) {
      _show('Could not send the voice recording.');
    } finally {
      if (recording != null) await _recorder.delete(recording);
      _finishing = false;
      if (mounted) {
        setState(() {
          _preparing = false;
          _recording = false;
          _releaseRequested = false;
        });
      }
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = _preparing || _finishing;
    return Semantics(
      button: true,
      label: widget.tooltip,
      hint: widget.tooltip,
      child: Listener(
        onPointerDown: widget.enabled ? (_) => unawaited(_start()) : null,
        onPointerUp: widget.enabled ? (_) => _release() : null,
        onPointerCancel: widget.enabled ? (_) => _release() : null,
        child: Tooltip(
          message: widget.tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.mic_none_rounded,
                      size: 23,
                      color: _recording
                          ? colors.error
                          : widget.enabled
                          ? colors.onSurfaceVariant
                          : colors.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
