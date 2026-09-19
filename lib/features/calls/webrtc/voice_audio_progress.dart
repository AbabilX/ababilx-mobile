/// Tracks fresh incoming audio, including after an ICE restart changes SSRCs.
class VoiceAudioProgress {
  Map<String, num> _packets = {};

  bool update(Map<String, num> packets) {
    final progressed = packets.entries.any((entry) {
      final previous = _packets[entry.key];
      return previous != null && entry.value > previous;
    });
    _packets = Map.of(packets);
    return progressed;
  }
}
