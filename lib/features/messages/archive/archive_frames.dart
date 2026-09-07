import 'dart:convert';

import '../data/models/chat_models.dart';

/// The archive is a stream of newline-delimited JSON frames, gzipped as a
/// whole and then sealed in fixed-size chunks.
///
/// NDJSON rather than a binary schema on purpose. A message already round-trips
/// losslessly through `ChatMessage.toJson`, and the local store keeps exactly
/// that JSON as its payload column — so a frame is bytes the device already
/// has, and the format cannot drift away from the model without a compile
/// error. Signal needs a protobuf schema because five clients in three
/// languages read its backups; one Dart client reading its own does not.
///
/// Order is part of the format, and one rule carries it: **anything referenced
/// must appear before the frame referencing it.** A `conv` precedes any `msg`
/// naming it, so an importer can create the conversation row before the first
/// message lands in it. Beyond that, messages are written oldest first, which
/// is the order the exporter's cursor produces and the order a restore should
/// replay.
///
/// An unknown frame type must be SKIPPED, never treated as corruption. That is
/// the whole of the forward-compatibility story: a newer app may write frames
/// this one has never heard of, and refusing them would turn a partial restore
/// into no restore at all.
class ArchiveFrame {
  const ArchiveFrame(this.type, this.data);

  static const header = 'header';
  static const conversation = 'conv';
  static const message = 'msg';

  /// The last frame of a complete archive.
  ///
  /// Load-bearing, and not obviously so: `gzip.decode` accepts a TRUNCATED
  /// member without complaint and returns what it managed to inflate. Per-chunk
  /// tags do not save us either — every chunk that did arrive is genuinely
  /// valid in its position. So an upload that died halfway would restore as a
  /// shorter, entirely plausible history with nothing anywhere reporting a
  /// problem. Requiring this frame is what turns that into a visible failure.
  static const end = 'end';

  final String type;
  final Map<String, dynamic> data;

  static ArchiveFrame headerFrame({
    required int createdAtMs,
    required String deviceId,
  }) => ArchiveFrame(header, {
    'v': archiveFormatVersion,
    'created_at_ms': createdAtMs,
    'device_id': deviceId,
  });

  static ArchiveFrame conversationFrame(ChatConversation conv) =>
      ArchiveFrame(conversation, {'c': conv.toJson()});

  static ArchiveFrame messageFrame(ChatMessage msg) =>
      ArchiveFrame(message, {'m': msg.toJson()});

  static ArchiveFrame endFrame({required int frames}) =>
      ArchiveFrame(end, {'frames': frames});

  Map<String, dynamic> toJson() => {'t': type, ...data};

  static ArchiveFrame? fromLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final json = jsonDecode(trimmed);
      if (json is! Map) return null;
      final map = Map<String, dynamic>.from(json);
      final type = map.remove('t');
      if (type is! String || type.isEmpty) return null;
      return ArchiveFrame(type, map);
    } catch (_) {
      // A single unreadable line is one lost frame, not a lost archive. The
      // chunk tag already proved the bytes are ours and untampered; anything
      // wrong past that point is a writer bug we should survive.
      return null;
    }
  }

  ChatMessage? asMessage() {
    final raw = data['m'];
    if (raw is! Map) return null;
    try {
      return ChatMessage.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  ChatConversation? asConversation() {
    final raw = data['c'];
    if (raw is! Map) return null;
    try {
      return ChatConversation.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
}

/// Bumped only for a change an older reader could not survive. Adding a frame
/// type is not one of those — unknown frames are skipped — so this should move
/// very rarely.
const int archiveFormatVersion = 1;
