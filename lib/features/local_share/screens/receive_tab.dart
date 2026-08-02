import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';
import '../providers/local_share_providers.dart';
import '../widgets/incoming_request_dialog.dart';
import '../widgets/transfer_progress_tile.dart';

class ReceiveTab extends ConsumerStatefulWidget {
  const ReceiveTab({super.key});

  @override
  ConsumerState<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends ConsumerState<ReceiveTab> {
  String? _ip;
  int? _port;

  @override
  void initState() {
    super.initState();
    ref.read(localServerServiceProvider).onReceiveRequested =
        (peer, files, decisionCompleter) => _promptAccept(peer, files, decisionCompleter);

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final ips = await ref.read(localIpServiceProvider).getLocalIps();
    final port = await ref.read(localShareSessionsProvider.notifier).startServer();
    if (!mounted) return;
    setState(() {
      _ip = ips.isNotEmpty ? ips.first : null;
      _port = port;
    });
  }

  Future<void> _promptAccept(
    LocalDevice peer,
    List<LocalFileDto> files,
    Completer<bool> decisionCompleter,
  ) async {
    if (!mounted) {
      decisionCompleter.complete(true);
      return;
    }
    final accepted = await IncomingRequestDialog.show(context, peer: peer, files: files);
    if (!decisionCompleter.isCompleted) decisionCompleter.complete(accepted);
  }

  @override
  void dispose() {
    ref.read(localServerServiceProvider).onReceiveRequested = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentDevice = ref.watch(currentLocalDeviceProvider);
    final sessions = ref
        .watch(localShareSessionsProvider)
        .values
        .where((s) => !s.isOutgoing)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final qrData = (_ip != null && _port != null) ? 'ababilx://$_ip:$_port' : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        ShellPillMetrics.contentBottomInset,
      ),
      children: [
        Center(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: qrData == null
                    ? const SizedBox(
                        width: 180,
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : QrImageView(
                        data: qrData,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                currentDevice.alias,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _ip != null && _port != null ? '$_ip:$_port' : 'Starting…',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Listening for nearby devices',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Incoming',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          for (final session in sessions) _ReceiveSessionCard(session: session),
        ],
      ],
    );
  }
}

class _ReceiveSessionCard extends StatelessWidget {
  const _ReceiveSessionCard({required this.session});

  final ShareSessionState session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From ${session.targetDevice.alias}',
            style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
          for (final f in session.files.values) TransferProgressTile(progress: f),
        ],
      ),
    );
  }
}
