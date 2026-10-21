/// The chat export zip (user's call, 2026-10-21): every chat on the phone,
/// plain and unprotected, readable on a computer and importable on any
/// AbabilX account.
///
/// ```
/// AbabilX-chats-<handle>-2026-10-21_17-01-38.zip
///   README.txt
///   chats.json                      the list below, read first by an import
///   chats/<folder>/messages.txt     one line per message, for people
///   chats/<folder>/messages.json    {chat, messages:[ExportedMessage]}
///   chats/<folder>/media/<n>-<name> the files that were on the phone
/// ```
///
/// Every name and key here is the import's contract: renaming one makes
/// older exports unreadable.
abstract final class ChatExportFormat {
  static const format = 'ababilx-chats';
  static const version = 1;
  static const manifest = 'chats.json';
  static const readme = 'README.txt';
  static const chatsDir = 'chats';
  static const messagesText = 'messages.txt';
  static const messagesJson = 'messages.json';
  static const mediaDir = 'media';

  static const readmeText =
      'AbabilX chat export\n'
      '\n'
      'This file is NOT encrypted. Anyone who has it can read every chat\n'
      'and open every photo and file in it.\n'
      '\n'
      'chats/<chat>/messages.txt   the messages, one per line\n'
      'chats/<chat>/media/         photos, videos, voice notes and files\n'
      '\n'
      'To read it in AbabilX: Settings > Backup > Import chats.\n';

  /// Letters, digits and a few separators only, so the name works on every
  /// file system and can never climb out of its folder.
  static String safeName(String name, {int max = 60}) {
    final cleaned = name
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}._ -]', unicode: true), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[ .]+|[ .]+$'), '');
    final cut = cleaned.length > max ? cleaned.substring(0, max) : cleaned;
    return cut.isEmpty ? 'file' : cut;
  }

  /// `012-Alice` — numbered, so two chats with one name never share a folder.
  static String chatFolder(int index, String title) =>
      '${index.toString().padLeft(3, '0')}-${safeName(title, max: 40)}';

  static String zipName(String handle, DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${at.year}-${two(at.month)}-${two(at.day)}_'
        '${two(at.hour)}-${two(at.minute)}-${two(at.second)}';
    final who = handle.isEmpty ? '' : '${safeName(handle, max: 32)}-';
    return 'AbabilX-chats-$who$stamp.zip';
  }

  /// `2026-10-21 17:01  Alice: hello` — local time, as the phone showed it.
  static String textLine(ExportedMessage m) {
    String two(int v) => v.toString().padLeft(2, '0');
    final at = DateTime.tryParse(m.at)?.toLocal();
    final when = at == null
        ? m.at
        : '${at.year}-${two(at.month)}-${two(at.day)} '
              '${two(at.hour)}:${two(at.minute)}';
    final parts = <String>[
      if (m.forwardedFrom != null) '[forwarded from ${m.forwardedFrom}]',
      if (m.replyTo != null) '[reply to ${m.replyTo!.sender}]',
      if (m.text.isNotEmpty) m.text,
      for (final f in m.files) '<${f.path ?? '${f.name} (not on the phone)'}>',
      if (m.edited) '(edited)',
    ];
    final who = m.kind == 'system' ? '' : '${m.sender}: ';
    return '$when  $who${parts.join(' ')}'.replaceAll('\n', '\n    ');
  }
}

class ExportedFile {
  const ExportedFile({
    required this.name,
    required this.type,
    required this.size,
    this.path,
  });

  final String name;
  final String type;
  final int size;

  /// Inside the chat's folder (`media/3-photo.jpg`); null when the file was
  /// not on the phone.
  final String? path;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'size': size,
    'path': ?path,
  };

  factory ExportedFile.fromJson(Map<String, dynamic> j) => ExportedFile(
    name: '${j['name'] ?? 'file'}',
    type: '${j['type'] ?? ''}',
    size: (j['size'] as num?)?.toInt() ?? 0,
    path: j['path'] as String?,
  );
}

class ExportedReply {
  const ExportedReply({required this.id, required this.sender, this.text});

  final String id;
  final String sender;
  final String? text;

  Map<String, dynamic> toJson() => {'id': id, 'sender': sender, 'text': ?text};

  factory ExportedReply.fromJson(Map<String, dynamic> j) => ExportedReply(
    id: '${j['id'] ?? ''}',
    sender: '${j['sender'] ?? ''}',
    text: j['text'] as String?,
  );
}

/// One message as the export carries it: readable text, never ciphertext.
class ExportedMessage {
  const ExportedMessage({
    required this.id,
    required this.at,
    required this.senderId,
    required this.sender,
    required this.kind,
    required this.text,
    this.edited = false,
    this.forwardedFrom,
    this.replyTo,
    this.files = const [],
  });

  final String id;

  /// ISO 8601, as the server stamped it.
  final String at;
  final String senderId;
  final String sender;

  /// `text`, `system`, `voice_call`, `group_call`, `webhook`, …
  final String kind;
  final String text;
  final bool edited;
  final String? forwardedFrom;
  final ExportedReply? replyTo;
  final List<ExportedFile> files;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at,
    'sender_id': senderId,
    'sender': sender,
    'kind': kind,
    'text': text,
    if (edited) 'edited': true,
    'forwarded_from': ?forwardedFrom,
    'reply_to': ?replyTo?.toJson(),
    if (files.isNotEmpty) 'files': [for (final f in files) f.toJson()],
  };

  factory ExportedMessage.fromJson(Map<String, dynamic> j) => ExportedMessage(
    id: '${j['id'] ?? ''}',
    at: '${j['at'] ?? ''}',
    senderId: '${j['sender_id'] ?? ''}',
    sender: '${j['sender'] ?? ''}',
    kind: '${j['kind'] ?? 'text'}',
    text: '${j['text'] ?? ''}',
    edited: j['edited'] == true,
    forwardedFrom: j['forwarded_from'] as String?,
    replyTo: j['reply_to'] is Map
        ? ExportedReply.fromJson(Map<String, dynamic>.from(j['reply_to']))
        : null,
    files: [
      for (final f in (j['files'] as List?) ?? const [])
        if (f is Map) ExportedFile.fromJson(Map<String, dynamic>.from(f)),
    ],
  );
}
