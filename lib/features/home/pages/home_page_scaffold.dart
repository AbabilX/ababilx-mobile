import 'package:flutter/material.dart';

import '../../messages/chat-pins/pinned_messages_chrome.dart';

/// A Home page: the app's floating capsule header (round back + title pill,
/// as on Tasks and Pinned messages) over a body that scrolls beneath it.
class HomePageScaffold extends StatelessWidget {
  const HomePageScaffold({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top + 64;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: body,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PinnedMessagesTopBar(title: title, bottomPadding: 12),
          ),
        ],
      ),
    );
  }
}

/// One quiet line where a list would be.
class HomePageEmpty extends StatelessWidget {
  const HomePageEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
