/// Tally of local ICE candidate types gathered for one call.
///
/// Exists because a stuck "Connecting…" looks identical no matter the cause.
/// The candidate mix tells them apart:
///   host only            → STUN/TURN unreachable; only same-LAN calls connect
///   host + srflx         → NAT traversal possible, no relay fallback
///   host + srflx + relay → healthy
class IceCandidateStats {
  int host = 0;
  int srflx = 0;
  int relay = 0;
  int other = 0;

  bool get hasReflexive => srflx > 0;
  bool get hasRelay => relay > 0;

  /// True when nothing but LAN-local candidates were gathered — the signature
  /// of an unreachable STUN/TURN server.
  bool get lanOnly => !hasReflexive && !hasRelay;

  void add(String candidate) {
    switch (_typeOf(candidate)) {
      case 'host':
        host++;
      case 'srflx' || 'prflx':
        srflx++;
      case 'relay':
        relay++;
      default:
        other++;
    }
  }

  /// Reads the `typ <value>` field of an SDP candidate line.
  static String _typeOf(String candidate) {
    final parts = candidate.split(RegExp(r'\s+'));
    final index = parts.indexOf('typ');
    if (index < 0 || index + 1 >= parts.length) return '';
    return parts[index + 1];
  }

  @override
  String toString() =>
      'host=$host srflx=$srflx relay=$relay other=$other'
      '${lanOnly ? ' LAN_ONLY(stun/turn unreachable)' : ''}';
}
