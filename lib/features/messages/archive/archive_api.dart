import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// What the server knows about a stored archive — which is nothing about its
/// contents. The salt is meaningless without the account identity, and the
/// chunk URLs address ciphertext.
class ArchiveManifest {
  const ArchiveManifest({
    required this.generation,
    required this.salt,
    required this.formatVersion,
    required this.chunkCount,
    required this.totalBytes,
    required this.chunks,
  });

  final int generation;
  final String salt;
  final int formatVersion;
  final int chunkCount;
  final int totalBytes;
  final List<String> chunks;

  factory ArchiveManifest.fromJson(Map<String, dynamic> json) =>
      ArchiveManifest(
        generation: (json['generation'] as num?)?.toInt() ?? 0,
        salt: json['salt'] as String? ?? '',
        formatVersion: (json['format_version'] as num?)?.toInt() ?? 1,
        chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
        totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
        chunks: (json['chunks'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ArchiveApi {
  const ArchiveApi(this._client);

  final ApiClient _client;

  /// Null when the account has never completed a backup. A half-uploaded
  /// first archive reads as null too — the server only publishes a generation
  /// once it commits, so a restore can never find an empty one.
  Future<ArchiveManifest?> fetchManifest() async {
    final res = await _client.get(ApiConstants.chatArchive);
    final data = unwrapApiData<Map<String, dynamic>>(res);
    if (data['exists'] != true) return null;
    return ArchiveManifest.fromJson(data);
  }

  Future<int> begin(String salt) async {
    final res = await _client.post(
      ApiConstants.chatArchiveBegin,
      data: {'salt': salt},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return (data['generation'] as num).toInt();
  }

  Future<String> presignChunk({
    required int generation,
    required int index,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.chatArchiveChunk,
      data: {'generation': generation, 'index': index, 'size_bytes': sizeBytes},
    );
    return unwrapApiData<Map<String, dynamic>>(res)['upload_url'] as String;
  }

  Future<void> commit({
    required int generation,
    required int chunkCount,
    required int totalBytes,
    required int formatVersion,
  }) => _client.post(
    ApiConstants.chatArchiveCommit,
    data: {
      'generation': generation,
      'chunk_count': chunkCount,
      'total_bytes': totalBytes,
      'format_version': formatVersion,
    },
  );

  /// Uploads one sealed chunk straight to storage. Uses a bare Dio, not the
  /// API client: the presigned URL carries its own auth and a Bearer token
  /// would make R2 reject the signature.
  Future<void> putChunk(String uploadUrl, List<int> bytes) => Dio().put(
    uploadUrl,
    data: Stream.value(bytes),
    options: Options(
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': bytes.length,
      },
    ),
  );

  Future<List<int>> getChunk(String url) async {
    final res = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const [];
  }
}
