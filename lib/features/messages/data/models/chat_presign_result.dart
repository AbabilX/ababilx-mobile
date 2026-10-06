import 'package:equatable/equatable.dart';

class ChatPresignResult extends Equatable {
  const ChatPresignResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.objectKey,
  });

  final String uploadUrl;
  final String publicUrl;
  final String objectKey;

  factory ChatPresignResult.fromJson(Map<String, dynamic> json) =>
      ChatPresignResult(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        objectKey: json['object_key'] as String? ?? '',
      );

  @override
  List<Object?> get props => [uploadUrl, publicUrl];
}
