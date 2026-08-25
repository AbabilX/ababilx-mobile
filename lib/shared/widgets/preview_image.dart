/// Minimal image payload shared by wall, CRM and chat previews.
class PreviewImage {
  const PreviewImage({
    required this.fileUrl,
    required this.fileName,
    this.localPath,
  });

  final String fileUrl;
  final String fileName;
  final String? localPath;
}
