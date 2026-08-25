import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable identity for a remote asset.
///
/// The server exposes no checksum or ETag for an attachment, so the remote URL
/// is the only thing two attachment rows pointing at the same R2 object share
/// — and forwarding does exactly that, copying `file_url` instead of
/// re-uploading. Hashing the *normalised* URL therefore gives free dedupe: a
/// forwarded video is already on disk the moment it arrives.
///
/// Query and fragment are dropped because R2 public URLs are unsigned; a
/// cache-busting `?v=2` must not fork the key into a second download.
String attachmentUrlKey(String remoteUrl) {
  final normalised = normaliseAttachmentUrl(remoteUrl);
  if (normalised.isEmpty) return '';
  return sha256.convert(utf8.encode(normalised)).toString().substring(0, 40);
}

/// Lowercased scheme + host, path verbatim (R2 object keys are
/// case-sensitive), no query, no fragment.
String normaliseAttachmentUrl(String remoteUrl) {
  final raw = remoteUrl.trim();
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return raw;
  return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}'
      '${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
}

/// Filename extension for the on-disk copy, sanitised to a short alphanumeric
/// token so a hostile `file_name` cannot escape the attachments directory.
/// Falls back to the content type's subtype, then `bin`.
String attachmentFileExtension(String fileName, String contentType) {
  final fromName = _sanitiseExtension(
    fileName.contains('.') ? fileName.split('.').last : '',
  );
  if (fromName.isNotEmpty) return fromName;
  final subtype = contentType.contains('/') ? contentType.split('/').last : '';
  final fromType = _sanitiseExtension(subtype.split(';').first);
  if (fromType.isNotEmpty) return fromType;
  return 'bin';
}

String _sanitiseExtension(String value) {
  final cleaned = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (cleaned.isEmpty || cleaned.length > 8) return '';
  return cleaned;
}
