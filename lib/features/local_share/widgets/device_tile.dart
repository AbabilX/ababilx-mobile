import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../models/device_model.dart';

/// Tappable card representing a discovered peer device.
class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onTap});

  final LocalDevice device;
  final VoidCallback onTap;

  List<List<dynamic>> get _icon {
    switch (device.deviceType) {
      case 'desktop':
        return HugeIcons.strokeRoundedComputer;
      case 'web':
        return HugeIcons.strokeRoundedGlobal;
      default:
        return HugeIcons.strokeRoundedSmartPhone01;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: ChatIcon(_icon, size: 24, color: scheme.primary),
              ),
              const SizedBox(height: 10),
              Text(
                device.alias,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                device.ip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
