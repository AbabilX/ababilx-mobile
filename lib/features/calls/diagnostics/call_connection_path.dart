import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_stats.dart';

enum CallPathKind { unknown, direct, relay }

/// How the call's media is travelling, as far as can be said without naming
/// any address. Only known candidate types and protocol names ever get in, so
/// nothing a stats report carries beside them can reach a log or a screen.
class CallConnectionPath {
  const CallConnectionPath({
    this.localType,
    this.remoteType,
    this.protocol,
    this.remoteProtocol,
    this.relayProtocol,
    this.confirmedByTransport = false,
    this.pairKey,
  });

  /// host, srflx, prflx or relay.
  final String? localType;
  final String? remoteType;

  /// udp or tcp on the selected pair, this phone's candidate.
  final String? protocol;
  final String? remoteProtocol;

  /// How this phone reaches its TURN server, when it uses one. A relay
  /// candidate says udp while this leg runs over TCP, which is the part that
  /// matters for voice.
  final String? relayProtocol;

  /// The transport named this pair. False is the fallback guess, which can be
  /// a stale pair while an ICE restart is under way.
  final bool confirmedByTransport;

  /// Tells one pair from another, for spotting a move. A hash, not an id.
  final int? pairKey;

  CallPathKind get kind {
    if (localType == 'relay' || remoteType == 'relay') {
      return CallPathKind.relay;
    }
    if (localType == null || remoteType == null) return CallPathKind.unknown;
    return CallPathKind.direct;
  }

  /// One log line. Types and protocols only.
  String describe() {
    final relay = relayProtocol == null ? '' : ' relay=$relayProtocol';
    return 'local=${localType ?? '?'}/${protocol ?? '?'} '
        'remote=${remoteType ?? '?'}/${remoteProtocol ?? '?'}$relay';
  }
}

const _candidateTypes = {'host', 'srflx', 'prflx', 'relay'};
const _protocols = {'udp', 'tcp', 'tls'};

String? _known(Object? value, Set<String> allowed) {
  if (value is! String) return null;
  final lower = value.toLowerCase();
  return allowed.contains(lower) ? lower : null;
}

/// The path out of one stats report: transport -> candidate pair -> the two
/// candidates. Goes through [selectedCandidatePair], the same pair the rest of
/// the call's measures read.
CallConnectionPath readConnectionPath(List<StatsReport> stats) {
  final pair = selectedCandidatePair(stats);
  if (pair == null) return const CallConnectionPath();
  final localId = pair['localCandidateId'];
  final remoteId = pair['remoteCandidateId'];
  Map<dynamic, dynamic>? local;
  Map<dynamic, dynamic>? remote;
  String? named;
  Map<dynamic, dynamic>? namedPair;
  for (final report in stats) {
    if (report.type == 'transport') {
      final id = report.values['selectedCandidatePairId'];
      if (id is String && id.isNotEmpty) named = id;
    } else if (report.type == 'local-candidate' && report.id == localId) {
      local = report.values;
    } else if (report.type == 'remote-candidate' && report.id == remoteId) {
      remote = report.values;
    }
  }
  for (final report in stats) {
    if (report.type == 'candidate-pair' && report.id == named) {
      namedPair = report.values;
    }
  }
  return CallConnectionPath(
    localType: _known(local?['candidateType'], _candidateTypes),
    remoteType: _known(remote?['candidateType'], _candidateTypes),
    protocol: _known(local?['protocol'], _protocols),
    remoteProtocol: _known(remote?['protocol'], _protocols),
    relayProtocol: _known(local?['relayProtocol'], _protocols),
    confirmedByTransport: identical(namedPair, pair),
    pairKey: Object.hash(localId, remoteId),
  );
}
