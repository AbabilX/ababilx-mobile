/// One contiguous piece of a file inside one media batch's stream.
class V2Segment {
  const V2Segment({
    required this.batch,
    required this.seg,
    required this.segs,
    required this.fileOffset,
    required this.length,
    required this.streamOffset,
  });

  final int batch;
  final int seg;
  final int segs;
  final int fileOffset;
  final int length;
  final int streamOffset;

  Map<String, dynamic> toJson() => {
    'batch': batch,
    'seg': seg,
    'segs': segs,
    'file_offset': fileOffset,
    'length': length,
    'stream_offset': streamOffset,
  };

  factory V2Segment.fromJson(Map<String, dynamic> j) => V2Segment(
    batch: j['batch'] as int,
    seg: j['seg'] as int,
    segs: j['segs'] as int,
    fileOffset: j['file_offset'] as int,
    length: j['length'] as int,
    streamOffset: j['stream_offset'] as int,
  );
}

/// One attachment file. `status` is `available`, `omitted` (vanished or
/// changed after planning — its bytes become zeros and the destination marks it
/// unavailable) or `missing` (the phone never held it).
class V2File {
  V2File({
    required this.urlKey,
    required this.fileName,
    required this.contentType,
    required this.size,
    required this.sha256,
    required this.localPath,
    required this.mtimeMs,
    required this.status,
    this.segments = const [],
  });

  final String urlKey;
  final String fileName;
  final String contentType;
  final int size;
  final String sha256;
  final String localPath;
  final int mtimeMs;
  String status;
  List<V2Segment> segments;

  Map<String, dynamic> toJson() => {
    'url_key': urlKey,
    'file_name': fileName,
    'content_type': contentType,
    'size': size,
    'sha256': sha256,
    'local_path': localPath,
    'mtime_ms': mtimeMs,
    'status': status,
    'segments': segments.map((s) => s.toJson()).toList(),
  };

  factory V2File.fromJson(Map<String, dynamic> j) => V2File(
    urlKey: j['url_key'] as String,
    fileName: j['file_name'] as String? ?? '',
    contentType: j['content_type'] as String? ?? '',
    size: j['size'] as int? ?? 0,
    sha256: j['sha256'] as String? ?? '',
    localPath: j['local_path'] as String? ?? '',
    mtimeMs: j['mtime_ms'] as int? ?? 0,
    status: j['status'] as String? ?? 'missing',
    segments: (j['segments'] as List? ?? [])
        .map((s) => V2Segment.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList(),
  );
}
