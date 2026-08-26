import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Result of asking the server where to put a profile image.
class ProfileUploadTarget {
  const ProfileUploadTarget({required this.uploadUrl, required this.publicUrl});

  factory ProfileUploadTarget.fromJson(Map<String, dynamic> json) =>
      ProfileUploadTarget(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
      );

  final String uploadUrl;
  final String publicUrl;

  bool get isValid => uploadUrl.isNotEmpty && publicUrl.isNotEmpty;
}

/// Avatar and cover uploads.
///
/// Three steps, same shape as chat attachments: ask for a presigned PUT, send
/// the bytes straight to storage with a bare Dio (the app's client would
/// attach our bearer token to someone else's host), then tell the server which
/// URL to keep. The server deletes the object the old URL pointed at, so a
/// changed avatar does not leave the previous one readable.
class ProfileMediaRepository {
  const ProfileMediaRepository(this._client);

  final ApiClient _client;

  Future<ProfileUploadTarget> presign({
    required String kind,
    required String contentType,
  }) async {
    final res = await _client.post(
      ApiConstants.meUploadPresign,
      data: {'kind': kind, 'content_type': contentType},
    );
    return ProfileUploadTarget.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  Future<void> upload(
    ProfileUploadTarget target,
    Uint8List bytes,
    String contentType,
  ) async {
    await Dio().put(
      target.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
  }

  /// Saves the URL. The response body is the server's own full-user shape
  /// rather than the merged one `AppUser` is built from, so it is deliberately
  /// not parsed here: the caller patches the avatar it just uploaded into
  /// local state and lets the next GET /api/me settle everything else.
  Future<void> saveAvatar(String publicUrl) async {
    await _client.patch(
      ApiConstants.meProfile,
      data: {'avatar_url': publicUrl},
    );
  }
}

final profileMediaRepositoryProvider = Provider<ProfileMediaRepository>(
  (ref) => ProfileMediaRepository(ref.watch(apiClientProvider)),
);
