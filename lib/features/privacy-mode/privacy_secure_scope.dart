import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks screenshots, screen recording and the Recents thumbnail while
/// [child] is on screen and [active] is true — Android `FLAG_SECURE`, through
/// the same counted channel Ghost Chat holds (`SecureWindowChannel.kt`).
///
/// Used where the OTHER person has privacy mode on: their DM and a call with
/// them. The hold is this phone's own promise, so a modified client or a
/// camera pointed at the screen gets around it; iOS has no equivalent yet.
///
/// Every scope takes at most one hold and gives back exactly that one: the
/// native side counts, so a leaked hold would block screenshots app-wide.
class PrivacySecureScope extends StatefulWidget {
  const PrivacySecureScope({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<PrivacySecureScope> createState() => _PrivacySecureScopeState();
}

class _PrivacySecureScopeState extends State<PrivacySecureScope> {
  static const _channel = MethodChannel('com.ababilx.app/secure_window');
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(PrivacySecureScope old) {
    super.didUpdateWidget(old);
    _sync(widget.active);
  }

  @override
  void dispose() {
    _sync(false);
    super.dispose();
  }

  Future<void> _sync(bool secure) async {
    if (!Platform.isAndroid || _held == secure) return;
    _held = secure;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Native half not in this build: nothing was held.
    } on PlatformException {
      // Never reached the window, so this scope did not change the count.
      _held = !secure;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
