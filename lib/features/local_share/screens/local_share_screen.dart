import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../widgets/share_tab_bar.dart';
import 'history_tab.dart';
import 'receive_tab.dart';
import 'send_tab.dart';

/// Fullscreen Local Share hub — carries its own Send/Receive pill tab bar,
/// entirely separate from the app's shell bottom navigation.
class LocalShareScreen extends StatefulWidget {
  const LocalShareScreen({super.key});

  @override
  State<LocalShareScreen> createState() => _LocalShareScreenState();
}

class _LocalShareScreenState extends State<LocalShareScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: ChatIcon(
                          HugeIcons.strokeRoundedArrowLeft01,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'Local Share',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: const [SendTab(), HistoryTab(), ReceiveTab()],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: ShareTabBar(
                selectedIndex: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
