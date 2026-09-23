import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../messages/chat-people/user_qr_payload.dart';
import '../../messages/chat_icon.dart';
import '../../profile/providers/profile_provider.dart';
import '../qr/my_qr_card.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../qr/my_qr_empty.dart';
import '../qr/my_qr_private.dart';

/// Your own QR code — Signal's "QR code" screen, reached from the button
/// beside your name in Settings.
///
/// That button used to open the scanner, which put the two halves of a QR
/// exchange on top of each other: whoever tapped it was ready to be scanned,
/// not to scan. The scanner now lives in the chat list header, and this screen
/// is the thing to hold up.
///
/// The code carries a handle, so an account without one has nothing to show.
/// That is the empty state, and it goes straight to picking a username rather
/// than explaining why the screen is blank.
class MyQrScreen extends ConsumerWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).valueOrNull;
    final username = user?.username ?? '';
    final private = ref.watch(privacyModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const Text('QR code'),
        actions: [
          if (username.isNotEmpty && !private)
            IconButton(
              tooltip: 'Change username',
              icon: const ChatIcon(HugeIcons.strokeRoundedEdit02),
              onPressed: () => context.push('/settings/username'),
            ),
        ],
      ),
      body: private
          ? const MyQrPrivate()
          : username.isEmpty
          ? const MyQrEmpty()
          : _Code(name: user?.name ?? '', username: username),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.name, required this.username});

  final String name;
  final String username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = buildUserQrPayload(username);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        MyQrCard(payload: payload, name: name, username: username),
        const SizedBox(height: 28),
        Text(
          'Anyone who scans this starts a chat with you. Your handle is '
          'public — the code carries nothing else.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const ChatIcon(HugeIcons.strokeRoundedCopy01, size: 18),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _share(),
                icon: const ChatIcon(HugeIcons.strokeRoundedShare01, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) => TextButton.icon(
            onPressed: () => QrLoginFlow.start(context, ref),
            icon: const ChatIcon(HugeIcons.strokeRoundedQrCode, size: 18),
            label: const Text('Scan someone else’s code'),
          ),
        ),
      ],
    );
  }

  /// Copy and share both carry the handle, not the `ababilx://` payload: a
  /// scheme URL pasted into a chat is dead text on any device without the app,
  /// while `@handle` is typed into people search and works everywhere.
  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '@$username'));
    if (context.mounted) showAppToast(context, 'Username copied');
  }

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(text: 'Message me on AbabilX: @$username'),
  );
}
