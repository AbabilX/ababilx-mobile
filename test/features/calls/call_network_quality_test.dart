import 'package:ababilx/features/calls/network/call_network_quality.dart';
import 'package:ababilx/features/calls/network/call_network_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

StatsReport _report(String id, String type, Map<String, dynamic> values) =>
    StatsReport(id, type, 0, values);

List<StatsReport> _stats({
  required int received,
  required int lost,
  double rtt = 0.05,
  double jitter = 0.005,
  double? remoteLost,
}) => [
  _report('t', 'transport', {'selectedCandidatePairId': 'p1'}),
  _report('p0', 'candidate-pair', {
    'state': 'succeeded',
    'nominated': true,
    'currentRoundTripTime': 0.9,
  }),
  _report('p1', 'candidate-pair', {'currentRoundTripTime': rtt}),
  _report('a', 'inbound-rtp', {
    'kind': 'audio',
    'packetsReceived': received,
    'packetsLost': lost,
    'jitter': jitter,
  }),
  if (remoteLost != null)
    _report('r', 'remote-inbound-rtp', {'fractionLost': remoteLost}),
];

void main() {
  group('own link', ownLinkTests);

  group('one reading', () {
    test('the worst measure decides', () {
      CallNetworkLevel rate({double? rtt, double? loss, double? jitter}) =>
          rateNetworkSample(
            CallNetworkSample(rttMs: rtt, lossPercent: loss, jitterMs: jitter),
          );
      expect(rate(), CallNetworkLevel.unknown);
      expect(rate(rtt: 80, loss: 0.5, jitter: 10), CallNetworkLevel.good);
      expect(rate(rtt: 320), CallNetworkLevel.weak);
      expect(rate(rtt: 80, loss: 4), CallNetworkLevel.weak);
      expect(rate(rtt: 80, jitter: 45), CallNetworkLevel.weak);
      expect(rate(rtt: 80, loss: 12), CallNetworkLevel.poor);
      expect(rate(rtt: 700, loss: 0), CallNetworkLevel.poor);
    });
  });

  group('trend', () {
    const good = CallNetworkSample(rttMs: 50, lossPercent: 0);
    const poor = CallNetworkSample(rttMs: 50, lossPercent: 20);

    test('the first reading shows at once', () {
      expect(CallNetworkTrend().add(poor), CallNetworkLevel.poor);
    });

    test('one bad reading does not raise a warning, two do', () {
      final trend = CallNetworkTrend()..add(good);
      expect(trend.add(poor), CallNetworkLevel.good);
      expect(trend.add(poor), CallNetworkLevel.poor);
    });

    test('a bad reading between good ones is forgotten', () {
      final trend = CallNetworkTrend()..add(good);
      trend.add(poor);
      trend.add(good);
      expect(trend.add(poor), CallNetworkLevel.good);
    });

    test('recovering takes three clean readings', () {
      final trend = CallNetworkTrend()..add(poor);
      expect(trend.add(good), CallNetworkLevel.poor);
      expect(trend.add(good), CallNetworkLevel.poor);
      expect(trend.add(good), CallNetworkLevel.good);
    });

    test('a reading with nothing in it changes nothing', () {
      final trend = CallNetworkTrend()..add(poor);
      expect(trend.add(const CallNetworkSample()), CallNetworkLevel.poor);
    });
  });

  group('stats', () {
    test('round trip comes from the pair in use', () {
      final sample = CallNetworkStatsReader().read(
        _stats(received: 100, lost: 0, rtt: 0.12),
      );
      expect(sample.rttMs, closeTo(120, 0.001));
      expect(sample.jitterMs, closeTo(5, 0.001));
      expect(sample.lossPercent, isNull);
    });

    test('loss is the share lost since the last report', () {
      final reader = CallNetworkStatsReader()
        ..read(_stats(received: 1000, lost: 0));
      final sample = reader.read(_stats(received: 1090, lost: 10));
      expect(sample.lossPercent, closeTo(10, 0.001));
      final clean = reader.read(_stats(received: 1190, lost: 10));
      expect(clean.lossPercent, 0);
    });

    test('the other side reporting loss of ours counts', () {
      final reader = CallNetworkStatsReader()
        ..read(_stats(received: 100, lost: 0));
      final sample = reader.read(
        _stats(received: 200, lost: 0, remoteLost: 0.08),
      );
      expect(sample.lossPercent, closeTo(8, 0.001));
    });

    test('numbers sent as text are read', () {
      final sample = CallNetworkStatsReader().read([
        _report('p', 'candidate-pair', {
          'selected': true,
          'currentRoundTripTime': '0.2',
        }),
      ]);
      expect(sample.rttMs, closeTo(200, 0.001));
    });
  });
}

// Own link, before anyone has answered.
void ownLinkTests() {
  test('a failed or slow round trip is poor, a quick one good', () {
    expect(rateOwnLink(null), CallNetworkLevel.poor);
    expect(rateOwnLink(1500), CallNetworkLevel.poor);
    expect(rateOwnLink(600), CallNetworkLevel.weak);
    expect(rateOwnLink(120), CallNetworkLevel.good);
  });
}
