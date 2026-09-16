import 'package:flutter/material.dart';

class JPackPathClipper extends CustomClipper<Path> {
  const JPackPathClipper(this.build);

  final Path Function(Size) build;

  @override
  Path getClip(Size size) => build(size);

  @override
  bool shouldReclip(JPackPathClipper old) => false;
}

/// A slow breath on the seal so it reads as the thing to press.
class JPackPulsingSeal extends StatefulWidget {
  const JPackPulsingSeal({super.key, required this.child});

  final Widget child;

  @override
  State<JPackPulsingSeal> createState() => _JPackPulsingSealState();
}

class _JPackPulsingSealState extends State<JPackPulsingSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
