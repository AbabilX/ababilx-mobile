import 'dart:convert';

/// One unfurled link, exactly the fields Signal-Android's `LinkPreview` carries
/// plus the image's real size — which Signal knows because the SENDER attached
/// the thumbnail, and we have to measure because we fetch on the reader's
/// device. It decides the big-image layout, so it is resolved once at load and
/// stored with the rest rather than measured again in every build.
class LinkPreviewData {
  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.imagePath,
    this.siteName,
    this.imageWidth,
    this.imageHeight,
  });

  final String url;
  final String? title;
  final String? description;

  /// Where the picture came from. Kept for the record only — nothing draws it,
  /// because a remote URL in an image widget is the request this design exists
  /// to avoid (see `link_preview_image_store.dart`).
  final String? imageUrl;

  /// The downloaded copy on this device. This is what the card draws.
  final String? imagePath;

  final String? siteName;
  final int? imageWidth;
  final int? imageHeight;

  /// Signal shows a card when it has EITHER a title or a picture
  /// (`LinkPreviewRepository`: an error only when both are missing). A page
  /// with neither is not a failure — it is a link with nothing to say.
  bool get isEmpty => (title ?? '').isEmpty && (imageUrl ?? '').isEmpty;

  LinkPreviewData withImage(String? path, int? width, int? height) =>
      LinkPreviewData(
        url: url,
        title: title,
        description: description,
        imageUrl: imageUrl,
        imagePath: path,
        siteName: siteName,
        imageWidth: width,
        imageHeight: height,
      );

  Map<String, dynamic> toJson() => {
    'url': url,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (imageUrl != null) 'image': imageUrl,
    if (imagePath != null) 'file': imagePath,
    if (siteName != null) 'site': siteName,
    if (imageWidth != null) 'w': imageWidth,
    if (imageHeight != null) 'h': imageHeight,
  };

  static LinkPreviewData? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    if (url is! String || url.isEmpty) return null;
    return LinkPreviewData(
      url: url,
      title: raw['title'] as String?,
      description: raw['description'] as String?,
      imageUrl: raw['image'] as String?,
      imagePath: raw['file'] as String?,
      siteName: raw['site'] as String?,
      imageWidth: (raw['w'] as num?)?.toInt(),
      imageHeight: (raw['h'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
