import 'package:flutter/material.dart';

import 'name_step.dart';
import 'phone_step.dart';
import 'photo_step.dart';
import 'username_step.dart';

/// Name → username → phone number → profile picture, one a screen. Every
/// step can be skipped: Skip fills a random name, a random unique handle and
/// a random icon picture (the phone number stays empty), so a new account is
/// in its chats in four taps.
class ProfileSetupFlow extends StatefulWidget {
  const ProfileSetupFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  static const steps = 4;

  @override
  State<ProfileSetupFlow> createState() => _ProfileSetupFlowState();
}

class _ProfileSetupFlowState extends State<ProfileSetupFlow> {
  int _step = 0;

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back walks the steps; it never leaves them.
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (_step > 0) setState(() => _step--);
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (_step) {
            0 => NameStep(onDone: _next),
            1 => UsernameStep(onDone: _next),
            2 => PhoneStep(onDone: _next),
            _ => PhotoStep(onDone: widget.onDone),
          },
        ),
      ),
    );
  }
}
