import 'package:flutter/material.dart';

import 'permission_intro.dart';
import 'permission_intro_page.dart';

/// Puts "Allow permissions" in front of [child] the first time after sign-in,
/// as Signal puts it in front of its restore screen. Shown once per install;
/// answered or not needed, it settles [PermissionIntro.settled] and steps
/// aside.
class PermissionIntroGate extends StatefulWidget {
  const PermissionIntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<PermissionIntroGate> createState() => _PermissionIntroGateState();
}

class _PermissionIntroGateState extends State<PermissionIntroGate> {
  /// Null while deciding; empty once the gate has stepped aside.
  List<IntroPermission>? _rows;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final show = await PermissionIntro.shouldShow();
    final rows = show ? await PermissionIntro.missing() : <IntroPermission>[];
    if (rows.isEmpty) PermissionIntro.settle(shown: false);
    if (mounted) setState(() => _rows = rows);
  }

  void _done() {
    PermissionIntro.settle(shown: true);
    setState(() => _rows = const []);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows != null && rows.isEmpty) return widget.child;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: rows == null
              ? const SizedBox.shrink()
              : PermissionIntroPage(rows: rows, onDone: _done),
        ),
      ),
    );
  }
}
