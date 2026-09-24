/// Minimal image payload shared by wall, CRM and chat previews.
class PreviewImage {
  const PreviewImage({
    required this.fileUrl,
    required this.fileName,
    this.localPath,
    this.identity = false,
  });

  final String fileUrl;
  final String fileName;
  final String? localPath;

  /// A profile, group or banner picture: read from [AvatarCache], where the
  /// avatar that was tapped already put it, so the viewer opens at once.
  final bool identity;
}
