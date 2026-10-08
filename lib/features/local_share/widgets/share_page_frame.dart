import 'package:flutter/material.dart';

/// A Local Share page: its header sits flat on top and the body starts under
/// it. Nothing scrolls beneath the header.
class SharePageFrame extends StatelessWidget {
  const SharePageFrame({super.key, required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        header,
        // The header already took the status bar's inset.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: body,
          ),
        ),
      ],
    ),
  );
}
