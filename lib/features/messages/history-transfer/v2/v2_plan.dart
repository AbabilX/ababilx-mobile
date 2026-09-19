import 'v2_plan_files.dart';

export 'v2_plan_files.dart';

/// The on-disk plan of one v2 transfer: which batches exist, what each holds,
/// and where every file's bytes sit. Written before the first upload and only
/// ever advanced, so a resumed run agrees with the server about what index k
/// of batch b contains. The transfer key is NOT in here — it lives in secure
/// storage (`v2_store.dart`).
class V2PlannedBatch {
  V2PlannedBatch({
    required this.batch,
    required this.kind,
    required this.isFinal,
    required this.chunkCount,
    required this.streamBytes,
    this.streamSha256 = '',
    this.messages = 0,
    this.conversations = 0,
    this.state = 'planned',
    this.uploadedThrough = -1,
    this.pageCount = 0,
  });

  final int batch;
  final String kind;
  bool isFinal;
  final int chunkCount;
  final int streamBytes;
  final String streamSha256;
  final int messages;
  final int conversations;

  /// planned → created → uploaded → paged → finalized → committed.
  String state;
  int uploadedThrough;
  int pageCount;

  bool get committed => state == 'committed';

  Map<String, dynamic> toJson() => {
    'batch': batch,
    'kind': kind,
    'final': isFinal,
    'chunk_count': chunkCount,
    'stream_bytes': streamBytes,
    'stream_sha256': streamSha256,
    'messages': messages,
    'conversations': conversations,
    'state': state,
    'uploaded_through': uploadedThrough,
    'page_count': pageCount,
  };

  factory V2PlannedBatch.fromJson(Map<String, dynamic> j) => V2PlannedBatch(
    batch: j['batch'] as int,
    kind: j['kind'] as String,
    isFinal: j['final'] == true,
    chunkCount: j['chunk_count'] as int,
    streamBytes: j['stream_bytes'] as int,
    streamSha256: j['stream_sha256'] as String? ?? '',
    messages: j['messages'] as int? ?? 0,
    conversations: j['conversations'] as int? ?? 0,
    state: j['state'] as String? ?? 'planned',
    uploadedThrough: j['uploaded_through'] as int? ?? -1,
    pageCount: j['page_count'] as int? ?? 0,
  );
}

class V2Plan {
  V2Plan({
    required this.transferId,
    required this.createdAtMs,
    required this.messageCount,
    required this.conversationCount,
    required this.batches,
    required this.files,
    this.inventorySent = false,
    this.sealSent = false,
  });

  final String transferId;
  final int createdAtMs;
  final int messageCount;
  final int conversationCount;
  final List<V2PlannedBatch> batches;
  final List<V2File> files;
  bool inventorySent;
  bool sealSent;

  int get lastBatch => batches.last.batch;
  Iterable<V2File> filesIn(int batch) =>
      files.where((f) => f.segments.any((s) => s.batch == batch));

  Map<String, dynamic> toJson() => {
    'v': 2,
    'transfer_id': transferId,
    'created_at_ms': createdAtMs,
    'messages': messageCount,
    'conversations': conversationCount,
    'inventory_sent': inventorySent,
    'seal_sent': sealSent,
    'batches': batches.map((b) => b.toJson()).toList(),
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory V2Plan.fromJson(Map<String, dynamic> j) => V2Plan(
    transferId: j['transfer_id'] as String,
    createdAtMs: j['created_at_ms'] as int? ?? 0,
    messageCount: j['messages'] as int? ?? 0,
    conversationCount: j['conversations'] as int? ?? 0,
    inventorySent: j['inventory_sent'] == true,
    sealSent: j['seal_sent'] == true,
    batches: (j['batches'] as List)
        .map((b) => V2PlannedBatch.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList(),
    files: (j['files'] as List)
        .map((f) => V2File.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList(),
  );
}
