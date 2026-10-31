import 'package:flutter/material.dart';

import '../diagnostics/call_diagnostics_state.dart';
import 'call_diagnostics_panel.dart';

/// The developer's way into [CallDiagnosticsPanel]: a long press on the call's
/// network badge. In a production build it is [child] and nothing else.
///
/// With no [child] (the badge has no level to draw, which is when numbers are
/// wanted most) it draws a small chip, but only while diagnostics are live.
class CallDiagnosticsEntry extends StatelessWidget {
  const CallDiagnosticsEntry({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    if (!kCallDiagnosticsEnabled) return child ?? const SizedBox.shrink();
    if (child != null) return _press(context, child);
    return ValueListenableBuilder(
      valueListenable: callDiagnostics,
      builder: (context, state, _) => state == null
          ? const SizedBox.shrink()
          : _press(
              context,
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  child: Text(
                    'Stats',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _press(BuildContext context, Widget child) => GestureDetector(
    onLongPress: () => showCallDiagnosticsPanel(context),
    child: child,
  );
}
