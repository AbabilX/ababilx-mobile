import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/chat_icon.dart';
import '../models/device_model.dart';
import '../models/session_state.dart';
import '../providers/local_share_providers.dart';
import '../services/discovery_service.dart';
import '../utils/file_dto_mapper.dart';
import '../widgets/device_tile.dart';
import '../widgets/transfer_progress_tile.dart';

class SendTab extends ConsumerStatefulWidget {
  const SendTab({super.key});

  @override
  ConsumerState<SendTab> createState() => _SendTabState();
}

class _SendTabState extends ConsumerState<SendTab> {
  // Discovery/server bootstrap is app-wide — see LocalShareSync — so this
  // tab only needs to watch nearbyDevicesProvider, not (re)start discovery.
  final List<PlatformFile> _picked = [];

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() => _picked.addAll(result.files));
  }

  Future<void> _scanQr() async {
    final controller = MobileScannerController();
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null) Navigator.of(context).pop(code);
          },
        ),
      ),
    );
    controller.dispose();
    if (scanned == null || !mounted) return;

    final uri = Uri.tryParse(scanned);
    if (uri == null || uri.host.isEmpty) return;

    final currentDevice = ref.read(currentLocalDeviceProvider);
    final device = await ref.read(localDiscoveryServiceProvider).fetchDeviceInfo(
          ip: uri.host,
          port: uri.hasPort ? uri.port : LocalDiscoveryService.defaultPort,
          currentDevice: currentDevice,
        );

    if (device != null) {
      ref.read(nearbyDevicesProvider.notifier).addDevice(device);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach that device')),
      );
    }
  }

  Future<void> _sendTo(LocalDevice device) async {
    if (_picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick files first')),
      );
      return;
    }

    final files = [
      for (var i = 0; i < _picked.length; i++)
        fileDtoFromPlatformFile(_picked[i], index: i),
    ];

    await ref.read(localShareSessionsProvider.notifier).sendFiles(
          targetDevice: device,
          files: files,
        );

    if (mounted) setState(() => _picked.clear());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final devices = ref.watch(nearbyDevicesProvider).values.toList();
    final sessions = ref
        .watch(localShareSessionsProvider)
        .values
        .where((s) => s.isOutgoing)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        ShellPillMetrics.contentBottomInset,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: ChatIcon(HugeIcons.strokeRoundedFolderTransfer, size: 18),
                label: Text('Pick files (${_picked.length})'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _scanQr,
              icon: ChatIcon(HugeIcons.strokeRoundedQrCode, size: 20),
              tooltip: 'Scan QR to add device',
            ),
          ],
        ),
        if (_picked.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _picked)
                Chip(
                  label: Text(
                    f.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () => setState(() => _picked.remove(f)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Nearby devices',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Searching for devices on your Wi-Fi…',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (_, i) => DeviceTile(
              device: devices[i],
              onTap: () => _sendTo(devices[i]),
            ),
          ),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Transfers',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          for (final session in sessions) _SendSessionCard(session: session),
        ],
      ],
    );
  }
}

class _SendSessionCard extends ConsumerWidget {
  const _SendSessionCard({required this.session});

  final ShareSessionState session;

  bool get _active =>
      session.status == TransferSessionStatus.sending ||
      session.status == TransferSessionStatus.waitingForRecipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'To ${session.targetDevice.alias}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (_active)
                TextButton(
                  onPressed: () => ref
                      .read(localShareSessionsProvider.notifier)
                      .cancelSession(session.sessionId),
                  child: const Text('Cancel'),
                ),
            ],
          ),
          for (final f in session.files.values) TransferProgressTile(progress: f),
        ],
      ),
    );
  }
}
