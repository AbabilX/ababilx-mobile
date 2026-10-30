import 'package:ababilx/features/calls/diagnostics/call_connection_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

StatsReport _candidate(
  String id,
  String type,
  String candidateType, {
  String protocol = 'udp',
  String? relayProtocol,
}) => StatsReport(id, type, 0, {
  'candidateType': candidateType,
  'protocol': protocol,
  'relayProtocol': ?relayProtocol,
  'address': '203.0.113.7',
  'ip': '203.0.113.7',
  'port': 40000,
  'url': 'turn:secret-host.example:3478',
  'usernameFragment': 'ufragvalue',
});

List<StatsReport> _stats({
  String localType = 'srflx',
  String remoteType = 'host',
  String localProtocol = 'udp',
  String? relayProtocol,
  String? named = 'good',
}) => [
  StatsReport('t', 'transport', 0, {'selectedCandidatePairId': ?named}),
  // A succeeded pair that is NOT carrying the call, listed first on purpose.
  StatsReport('stale', 'candidate-pair', 0, {
    'state': 'succeeded',
    'nominated': true,
    'localCandidateId': 'staleL',
    'remoteCandidateId': 'staleR',
  }),
  StatsReport('good', 'candidate-pair', 0, {
    'state': 'succeeded',
    'nominated': true,
    'localCandidateId': 'l',
    'remoteCandidateId': 'r',
    'currentRoundTripTime': 0.05,
  }),
  _candidate('staleL', 'local-candidate', 'relay'),
  _candidate('staleR', 'remote-candidate', 'relay'),
  _candidate(
    'l',
    'local-candidate',
    localType,
    protocol: localProtocol,
    relayProtocol: relayProtocol,
  ),
  _candidate('r', 'remote-candidate', remoteType),
];

void main() {
  test('the pair comes from the transport, not the first that succeeded', () {
    final path = readConnectionPath(_stats());
    expect(path.localType, 'srflx');
    expect(path.remoteType, 'host');
    expect(path.confirmedByTransport, isTrue);
    expect(path.kind, CallPathKind.direct);
  });

  test('host, srflx and prflx on both ends are direct', () {
    for (final local in ['host', 'srflx', 'prflx']) {
      for (final remote in ['host', 'srflx', 'prflx']) {
        expect(
          readConnectionPath(_stats(localType: local, remoteType: remote)).kind,
          CallPathKind.direct,
        );
      }
    }
  });

  test('a relay on either end is TURN', () {
    expect(
      readConnectionPath(_stats(localType: 'relay')).kind,
      CallPathKind.relay,
    );
    expect(
      readConnectionPath(_stats(remoteType: 'relay')).kind,
      CallPathKind.relay,
    );
  });

  test('the protocol and the relay leg are both reported', () {
    final tcp = readConnectionPath(_stats(localProtocol: 'tcp'));
    expect(tcp.protocol, 'tcp');
    final relay = readConnectionPath(
      _stats(localType: 'relay', relayProtocol: 'tcp'),
    );
    expect(relay.protocol, 'udp');
    expect(relay.relayProtocol, 'tcp');
  });

  test('without a transport a fallback pair is marked unconfirmed', () {
    final path = readConnectionPath(_stats(named: null));
    expect(path.confirmedByTransport, isFalse);
    expect(path.kind, isNot(CallPathKind.unknown));
  });

  test('no pair, or a pair with no candidates, is unknown', () {
    expect(readConnectionPath(const []).kind, CallPathKind.unknown);
    final orphan = readConnectionPath([
      StatsReport('t', 'transport', 0, {'selectedCandidatePairId': 'p'}),
      StatsReport('p', 'candidate-pair', 0, {'state': 'succeeded'}),
    ]);
    expect(orphan.kind, CallPathKind.unknown);
  });

  test('one known type that is not a relay stays unknown', () {
    final path = readConnectionPath([
      StatsReport('t', 'transport', 0, {'selectedCandidatePairId': 'p'}),
      StatsReport('p', 'candidate-pair', 0, {
        'localCandidateId': 'l',
        'remoteCandidateId': 'missing',
      }),
      _candidate('l', 'local-candidate', 'host'),
    ]);
    expect(path.kind, CallPathKind.unknown);
  });

  test('a move to another pair changes the key, same pair keeps it', () {
    final before = readConnectionPath(_stats());
    final same = readConnectionPath(_stats());
    final moved = readConnectionPath([..._stats(named: 'stale')]);
    expect(same.pairKey, before.pairKey);
    expect(moved.pairKey, isNot(before.pairKey));
    expect(moved.kind, CallPathKind.relay);
  });

  test('nothing network-identifying survives into the path or its log', () {
    final path = readConnectionPath(
      _stats(localType: 'relay', relayProtocol: 'tls'),
    );
    final text = '${path.describe()} $path';
    for (final secret in [
      '203.0.113.7',
      '40000',
      'secret-host',
      'ufragvalue',
      'staleL',
    ]) {
      expect(text, isNot(contains(secret)));
    }
    expect(path.describe(), 'local=relay/udp remote=host/udp relay=tls');
  });

  test('an unexpected value is not passed through as a type', () {
    final path = readConnectionPath([
      StatsReport('t', 'transport', 0, {'selectedCandidatePairId': 'p'}),
      StatsReport('p', 'candidate-pair', 0, {
        'localCandidateId': 'l',
        'remoteCandidateId': 'r',
      }),
      StatsReport('l', 'local-candidate', 0, {
        'candidateType': '203.0.113.7',
        'protocol': '203.0.113.7',
        'relayProtocol': '203.0.113.7',
      }),
      StatsReport('r', 'remote-candidate', 0, {'candidateType': 7}),
    ]);
    expect(path.describe(), isNot(contains('203.0.113.7')));
    expect(path.localType, isNull);
    expect(path.protocol, isNull);
    expect(path.relayProtocol, isNull);
    expect(path.remoteType, isNull);
  });
}
