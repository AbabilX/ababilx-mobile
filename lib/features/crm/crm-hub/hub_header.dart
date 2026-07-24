import 'package:flutter/material.dart';

/// Centered CRM title for the hub app bar area.
class CrmHubHeader extends StatelessWidget implements PreferredSizeWidget {
  const CrmHubHeader({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );
  }
}
