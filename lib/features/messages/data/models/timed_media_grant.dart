/// What `POST .../messages/:id/viewed` hands the receiver of a timed photo:
/// the one thing every other read withholds.
///
/// For a photo its sender encrypted (server 0168) that is the URL of the
/// ciphertext together with its sealed key — the key is held back with the
/// URL, and the two arrive together when the photo is opened.
class TimedMediaGrant {
  const TimedMediaGrant({
    required this.url,
    this.encMeta = '',
    this.encNonce = '',
    this.encKeyVersion = 0,
  });

  final String url;
  final String encMeta;
  final String encNonce;
  final int encKeyVersion;

  bool get isSealed => encMeta.isNotEmpty;

  factory TimedMediaGrant.fromJson(Map<String, dynamic> json) =>
      TimedMediaGrant(
        url: json['file_url'] as String? ?? '',
        encMeta: json['enc_meta'] as String? ?? '',
        encNonce: json['enc_nonce'] as String? ?? '',
        encKeyVersion: (json['enc_key_version'] as num?)?.toInt() ?? 0,
      );
}
