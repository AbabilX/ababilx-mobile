import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/onboarding/onboarding_option_card.dart';
import 'transfer_chats_copy.dart';
import 'transfer_receive_screen.dart';

/// "Transfer chats from another phone" for the restore-account screen, or
/// null off Android. [onDone] runs once the chats and the message key are on
/// this phone, and is what leaves the restore screen.
Widget? transferChatsOption({
  required bool busy,
  required VoidCallback onDone,
}) => Platform.isAndroid
    ? TransferChatsCard(enabled: !busy, onDone: onDone)
    : null;

class TransferChatsCard extends ConsumerWidget {
  const TransferChatsCard({
    super.key,
    required this.enabled,
    required this.onDone,
  });

  final bool enabled;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingOptionCard(
    icon: HugeIcons.strokeRoundedSmartPhone02,
    title: transferText(ref, 'card_title'),
    subtitle: transferText(ref, 'card_body'),
    enabled: enabled,
    onTap: () async {
      if (await TransferReceiveScreen.open(context)) onDone();
    },
  );
}
