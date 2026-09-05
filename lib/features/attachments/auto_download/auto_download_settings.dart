import '../../../core/network/network_class.dart';
import '../../messages/data/models/chat_attachment.dart';

/// The four kinds of attachment auto-download can be told about separately.
///
/// Deliberately coarser than the renderer's own type checks: a user thinks in
/// "photos, video, voice notes, files", not in MIME types.
enum AutoDownloadMedia {
  photos('Photos'),
  audio('Audio'),
  video('Video'),
  documents('Documents');

  const AutoDownloadMedia(this.label);

  final String label;
}

/// Which knob governs this attachment. PDFs and everything unrecognised are
/// documents; the image / video / audio order matches the model's own
/// precedence, where `.webm` is video before it is audio.
AutoDownloadMedia autoDownloadMediaOf(ChatMessageAttachment attachment) {
  if (attachment.isImage) return AutoDownloadMedia.photos;
  if (attachment.isVideo) return AutoDownloadMedia.video;
  if (attachment.isAudio) return AutoDownloadMedia.audio;
  return AutoDownloadMedia.documents;
}

/// One network set per media type, stored as a bitmask.
///
/// Immutable: a change produces a new value, so a rebuild cannot half-apply.
class AutoDownloadSettings {
  const AutoDownloadSettings(this._masks);

  final Map<AutoDownloadMedia, int> _masks;

  /// What the app did before this screen existed, with one deliberate change:
  /// **roaming is off everywhere**.
  ///
  /// Photos and voice notes used to land on any connection at all, roaming
  /// included, which is the one case where a silent download costs real money.
  /// Video and documents stay off entirely, as they always were — the
  /// expensive ones still wait for a tap.
  static const defaults = AutoDownloadSettings({
    AutoDownloadMedia.photos: 3, // wifi | cellular
    AutoDownloadMedia.audio: 3, // wifi | cellular
    AutoDownloadMedia.video: 0,
    AutoDownloadMedia.documents: 0,
  });

  int maskFor(AutoDownloadMedia media) => _masks[media] ?? 0;

  Set<AutoDownloadNetwork> networksFor(AutoDownloadMedia media) {
    final mask = maskFor(media);
    return {
      for (final network in AutoDownloadNetwork.values)
        if (mask & network.bit != 0) network,
    };
  }

  /// The whole decision, given what this connection costs. [NetworkClass.offline]
  /// resolves to no matching box, so nothing starts with no route out.
  bool allows(AutoDownloadMedia media, NetworkClass network) {
    final on = AutoDownloadNetwork.forClass(network);
    return on != null && maskFor(media) & on.bit != 0;
  }

  AutoDownloadSettings withNetworks(
    AutoDownloadMedia media,
    Set<AutoDownloadNetwork> networks,
  ) => AutoDownloadSettings({
    ..._masks,
    media: networks.fold(0, (mask, network) => mask | network.bit),
  });

  /// `Wi-Fi, Cellular` — or `Never`, which is worth spelling out rather than
  /// showing an empty value the user reads as "not loaded yet".
  String describe(AutoDownloadMedia media) {
    final networks = networksFor(media);
    if (networks.isEmpty) return 'Never';
    if (networks.length == AutoDownloadNetwork.values.length) return 'Always';
    return AutoDownloadNetwork.values
        .where(networks.contains)
        .map((n) => n.label)
        .join(', ');
  }
}
