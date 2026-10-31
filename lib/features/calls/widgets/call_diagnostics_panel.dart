import 'package:flutter/material.dart';

import '../diagnostics/call_audio_health.dart';
import '../diagnostics/call_diagnostics_format.dart';
import '../diagnostics/call_diagnostics_state.dart';
import '../network/call_network_quality.dart';

/// Opens the developer panel over the call. See [kCallDiagnosticsEnabled].
Future<void> showCallDiagnosticsPanel(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CallDiagnosticsPanel(),
    );

/// The live call's measurements as numbers, for a developer. Reads only
/// [callDiagnostics], so it is the only thing a reading rebuilds.
class CallDiagnosticsPanel extends StatelessWidget {
  const CallDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: callDiagnostics,
      builder: (context, state, _) {
        if (state == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No readings yet: the call has not connected.'),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _Body(state: state),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final CallDiagnosticsState state;

  @override
  Widget build(BuildContext context) {
    final audio = state.audio;
    final path = state.path;
    final network = state.network;
    final health = state.health;
    final summary = state.summary;
    final colors = Theme.of(context).colorScheme;
    final bad = colors.error;
    final fine = colors.primary;
    final healthColor = switch (health.status) {
      CallAudioHealth.healthy => fine,
      CallAudioHealth.settling => colors.outline,
      _ => bad,
    };
    final levelColor = switch (state.networkLevel) {
      CallNetworkLevel.good => fine,
      CallNetworkLevel.unknown => colors.outline,
      _ => bad,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row('Audio health', healthLabel(health.status), dot: healthColor),
        const _Heading('CONNECTION'),
        _Row('Connection state', state.connectionState ?? notMeasured),
        _Row('ICE state', state.iceState ?? notMeasured),
        _Row('Path', pathLabel(path)),
        _Row('Transport', transportLabel(path)),
        _Row('Candidates', candidatesLabel(path)),
        const _Heading('AUDIO'),
        _Row('Codec received', audio.inboundCodec ?? notMeasured),
        _Row('Codec sent', audio.outboundCodec ?? notMeasured),
        _Row('Incoming bitrate', formatBitrate(audio.inboundBps)),
        _Row('Outgoing bitrate', formatBitrate(audio.outboundBps)),
        _Row('Packet loss', formatPercent(audio.lossPercent)),
        _Row('Far side lost', formatPercent(audio.remoteLossPercent)),
        _Row('Jitter', formatMs(audio.jitterMs)),
        _Row('Jitter buffer delay', formatMs(audio.jitterBufferDelayMs)),
        _Row('Concealment', formatPercent(audio.concealmentPercent)),
        _Row('Concealment events', formatCount(audio.concealmentEventsDelta)),
        _Row('Packets received', formatCount(audio.packetsReceived)),
        _Row('Packets sent', formatCount(audio.packetsSent)),
        _Row('Retransmitted', formatCount(audio.retransmittedDelta)),
        _Row('Audio level', formatCount(audio.audioLevel)),
        const _Heading('NETWORK'),
        _Row('RTT', formatMs(network.rttMs)),
        _Row('Available outgoing', formatBitrate(state.availableOutgoingBps)),
        _Row('Network quality', state.networkLevel.name, dot: levelColor),
        const _Heading('LAST 2 MINUTES'),
        _Row('Readings', '${summary.readings}'),
        _Row('Troubled readings', '${summary.troubledReadings}'),
        _Row('Average loss', formatPercent(summary.averageLossPercent)),
        _Row('Worst loss', formatPercent(summary.maxLossPercent)),
        _Row('Average jitter', formatMs(summary.averageJitterMs)),
        _Row('Average RTT', formatMs(summary.averageRttMs)),
        _Row(
          'Average concealment',
          formatPercent(summary.averageConcealmentPercent),
        ),
        if (health.unsupported.isNotEmpty) ...[
          const _Heading('NOT REPORTED BY THIS PLATFORM'),
          Text(health.unsupported.join(', ')),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.dot});

  final String label;
  final String value;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final dotColor = dot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (dotColor != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
