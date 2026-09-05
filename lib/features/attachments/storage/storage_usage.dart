import '../../messages/data/models/chat_attachment.dart';

/// How downloaded bytes are grouped on the Manage-storage screen.
///
/// Same four buckets the auto-download settings use, on purpose: a user who
/// sees "Video 1.2 GB" and wants it to stop growing must find the switch
/// under the same word.
enum StorageBucket {
  photos('Photos'),
  videos('Videos'),
  audio('Audio'),
  documents('Files');

  const StorageBucket(this.label);

  final String label;
}

/// Classifies a stored blob from what the row remembers about it.
///
/// Reuses [ChatMessageAttachment]'s own type checks rather than a second
/// implementation — the blob store keeps the file name and content type for
/// exactly this reason, and two different answers for one file would put a
/// photo in the bar and a document in the list.
StorageBucket storageBucketOf({
  required String fileName,
  required String contentType,
}) {
  final probe = ChatMessageAttachment(
    id: '',
    messageId: '',
    fileName: fileName,
    fileUrl: '',
    contentType: contentType,
    sizeBytes: 0,
    uploadedBy: '',
    createdAt: '',
  );
  if (probe.isImage) return StorageBucket.photos;
  if (probe.isVideo) return StorageBucket.videos;
  if (probe.isAudio) return StorageBucket.audio;
  return StorageBucket.documents;
}

/// What Manage storage draws: bytes and a count per bucket.
class StorageUsage {
  const StorageUsage({this.bytes = const {}, this.counts = const {}});

  final Map<StorageBucket, int> bytes;
  final Map<StorageBucket, int> counts;

  static const empty = StorageUsage();

  int bytesFor(StorageBucket bucket) => bytes[bucket] ?? 0;
  int countFor(StorageBucket bucket) => counts[bucket] ?? 0;

  int get total => bytes.values.fold(0, (sum, value) => sum + value);
  int get count => counts.values.fold(0, (sum, value) => sum + value);
  bool get isEmpty => total == 0;

  /// Buckets with something in them, biggest first — the legend's order.
  List<StorageBucket> get occupied {
    final used = StorageBucket.values.where((b) => bytesFor(b) > 0).toList()
      ..sort((a, b) => bytesFor(b).compareTo(bytesFor(a)));
    return used;
  }
}

/// One downloaded file, as Review storage lists it.
class StorageItem {
  const StorageItem({
    required this.urlKey,
    required this.fileName,
    required this.contentType,
    required this.bytes,
    required this.localPath,
    this.downloadedAtMs = 0,
    this.conversationId = '',
  });

  final String urlKey;
  final String fileName;
  final String contentType;
  final int bytes;
  final String localPath;
  final int downloadedAtMs;
  final String conversationId;

  StorageBucket get bucket =>
      storageBucketOf(fileName: fileName, contentType: contentType);
}

/// One chat's share of the store.
///
/// A file forwarded into three chats is counted in all three, so these do not
/// sum to [StorageUsage.total] — the bytes exist once. The screen says so
/// rather than inventing a split that would be wrong either way.
class ConversationStorage {
  const ConversationStorage({
    required this.conversationId,
    required this.bytes,
    required this.count,
  });

  final String conversationId;
  final int bytes;
  final int count;
}
