import 'package:audioplayers/audioplayers.dart';

/// Stable playback identity plus the bytes source.
///
/// Wall and CRM use [UrlSource]; downloaded chat voice notes use
/// [DeviceFileSource]. The singleton player compares [id], not implementation
/// details, so switching recordings still stops the previous one.
class AudioSourceRef {
  const AudioSourceRef({required this.id, required this.source});

  factory AudioSourceRef.url(String url) =>
      AudioSourceRef(id: url, source: UrlSource(url));

  factory AudioSourceRef.file(String path) =>
      AudioSourceRef(id: path, source: DeviceFileSource(path));

  final String id;
  final Source source;
}
