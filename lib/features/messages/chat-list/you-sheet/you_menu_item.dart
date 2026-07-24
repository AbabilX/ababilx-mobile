import 'package:flutter/material.dart';

import '../../chat_icon.dart';

class YouMenuItem extends StatelessWidget {
  const YouMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            ChatIcon(icon, size: 22, color: colors.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
