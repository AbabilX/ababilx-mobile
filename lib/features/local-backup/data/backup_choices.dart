/// What the person chose to back up (Settings → Backup → Local backup).
///
/// Text is not a choice — a backup without messages is not a backup — so it
/// has no field. Media kinds default to the small, precious ones: photos and
/// voice notes on, videos and documents off, because those two are what fills
/// a folder and most people never miss them.
class BackupChoices {
  const BackupChoices({
    this.photos = true,
    this.voiceNotes = true,
    this.videos = false,
    this.documents = false,
    this.directMessages = true,
    this.groups = true,
  });

  final bool photos;
  final bool voiceNotes;
  final bool videos;
  final bool documents;
  final bool directMessages;
  final bool groups;

  /// Both chat switches off means there is nothing to back up. The screen says
  /// so, and a run refuses instead of writing an empty file that would push a
  /// real one out of the folder.
  bool get anyChats => directMessages || groups;

  BackupChoices copyWith({
    bool? photos,
    bool? voiceNotes,
    bool? videos,
    bool? documents,
    bool? directMessages,
    bool? groups,
  }) => BackupChoices(
    photos: photos ?? this.photos,
    voiceNotes: voiceNotes ?? this.voiceNotes,
    videos: videos ?? this.videos,
    documents: documents ?? this.documents,
    directMessages: directMessages ?? this.directMessages,
    groups: groups ?? this.groups,
  );

  Map<String, dynamic> toJson() => {
    'photos': photos,
    'voice_notes': voiceNotes,
    'videos': videos,
    'documents': documents,
    'dms': directMessages,
    'groups': groups,
  };

  factory BackupChoices.fromJson(Map<String, dynamic> json) {
    const d = BackupChoices();
    bool read(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return BackupChoices(
      photos: read('photos', d.photos),
      voiceNotes: read('voice_notes', d.voiceNotes),
      videos: read('videos', d.videos),
      documents: read('documents', d.documents),
      directMessages: read('dms', d.directMessages),
      groups: read('groups', d.groups),
    );
  }
}
