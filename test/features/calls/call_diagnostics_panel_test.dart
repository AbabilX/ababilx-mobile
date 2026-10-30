import 'package:ababilx/features/calls/diagnostics/call_audio_health.dart';
import 'package:ababilx/features/calls/diagnostics/call_audio_stats.dart';
import 'package:ababilx/features/calls/diagnostics/call_connection_path.dart';
import 'package:ababilx/features/calls/diagnostics/call_diagnostics_state.dart';
import 'package:ababilx/features/calls/network/call_network_quality.dart';
import 'package:ababilx/features/calls/widgets/call_diagnostics_entry.dart';
import 'package:ababilx/features/calls/widgets/call_diagnostics_panel.dart';
import 'package:ababilx/features/calls/widgets/call_network_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _state = CallDiagnosticsState(
  updatedAtMs: 1,
  connectionState: 'connected',
  iceState: 'completed',
  audio: CallAudioSample(
    hasInbound: true,
    hasOutbound: true,
    inboundCodec: 'audio/opus',
    inboundBps: 32000,
    lossPercent: 2,
    jitterMs: 12,
  ),
  network: CallNetworkSample(rttMs: 80),
  networkLevel: CallNetworkLevel.good,
  path: CallConnectionPath(
    localType: 'relay',
    remoteType: 'host',
    protocol: 'udp',
    confirmedByTransport: true,
  ),
  health: CallAudioHealthReport(status: CallAudioHealth.healthy),
);

void main() {
  tearDown(() {
    callDiagnostics.value = null;
    callNetworkQuality.value = CallNetworkLevel.unknown;
  });

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('the panel draws the three sections and the live figures', (
    tester,
  ) async {
    callDiagnostics.value = _state;
    await pump(tester, const CallDiagnosticsPanel());
    for (final text in [
      'CONNECTION',
      'AUDIO',
      'NETWORK',
      'TURN relay',
      'audio/opus',
      '32 kbps',
      '2.0 %',
      '12 ms',
      '80 ms',
      'Healthy',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('n/a'), findsWidgets);
  });

  testWidgets('with no reading the panel says so', (tester) async {
    await pump(tester, const CallDiagnosticsPanel());
    expect(find.textContaining('No readings'), findsOneWidget);
  });

  testWidgets('the panel follows the notifier', (tester) async {
    callDiagnostics.value = _state;
    await pump(tester, const CallDiagnosticsPanel());
    callDiagnostics.value = const CallDiagnosticsState(
      updatedAtMs: 2,
      health: CallAudioHealthReport(status: CallAudioHealth.packetStall),
    );
    await tester.pump();
    expect(find.textContaining('stalled'), findsWidgets);
  });

  testWidgets('a long press on the live badge opens the panel', (tester) async {
    callNetworkQuality.value = CallNetworkLevel.good;
    callDiagnostics.value = _state;
    await pump(tester, const CallNetworkBadge());
    await tester.longPress(find.text('Good network'));
    await tester.pumpAndSettle();
    expect(find.byType(CallDiagnosticsPanel), findsOneWidget);
  });

  testWidgets('the ringing badge has no way in', (tester) async {
    callOwnLinkQuality.value = CallNetworkLevel.good;
    addTearDown(() => callOwnLinkQuality.value = CallNetworkLevel.unknown);
    await pump(tester, const CallNetworkBadge(ownLink: true));
    await tester.longPress(find.text('Good network'));
    await tester.pumpAndSettle();
    expect(find.byType(CallDiagnosticsPanel), findsNothing);
  });

  testWidgets('no reading level, but diagnostics live: a way in remains', (
    tester,
  ) async {
    callDiagnostics.value = _state;
    await pump(tester, const CallNetworkBadge());
    expect(find.byType(CallDiagnosticsEntry), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
  });

  testWidgets('no reading level and no diagnostics: still nothing drawn', (
    tester,
  ) async {
    await pump(tester, const CallNetworkBadge());
    expect(find.byType(Text), findsNothing);
  });
}
