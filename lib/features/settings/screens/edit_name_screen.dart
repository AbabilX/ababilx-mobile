import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../profile/providers/profile_provider.dart';
import '../display-name/display_name_rules.dart';

/// Edit your own display name — Signal's "Profile name" screen.
///
/// This is the name every other account sees: chat list rows, message bubbles,
/// group member lists, workspace rosters. There is no separate nickname field
/// behind it; the server writes `users.name`, which all of those already read.
class EditNameScreen extends ConsumerStatefulWidget {
  const EditNameScreen({super.key});

  @override
  ConsumerState<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends ConsumerState<EditNameScreen> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(profileProvider).valueOrNull?.name ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _stored => ref.read(profileProvider).valueOrNull?.name ?? '';

  bool get _canSave {
    if (_saving) return false;
    final next = normalizeDisplayName(_ctrl.text);
    return isValidDisplayName(_ctrl.text) && next != _stored;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .updateName(normalizeDisplayName(_ctrl.text));
      if (mounted) popOrGoHome(context);
    } catch (_) {
      // The typed name stays in the field — losing it to a flaky connection
      // would be worse than the error line.
      if (mounted) {
        setState(() => _error = 'Could not save your name. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final left = displayNameRunesLeft(_ctrl.text);

    return Scaffold(
      appBar: AppBar(
        leading: AppBarBackButton(onPressed: _saving ? null : () => popOrGoHome(context)),
        title: const Text('Your name'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Name',
              border: const OutlineInputBorder(),
              errorText: _error,
              // Only nag near the cap — a counter on every screen is noise.
              counterText: left <= 10 ? '$left left' : '',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This is the name people see next to your messages, in group '
            'member lists and in your workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
