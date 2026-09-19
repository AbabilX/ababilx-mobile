import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// One column of email-auth content under a plain app bar. Every step of the
/// flow (sign in, sign up, forgot, code) shares it so they read as one flow.
class EmailAuthScaffold extends StatelessWidget {
  const EmailAuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class EmailAuthField extends ConsumerStatefulWidget {
  const EmailAuthField({
    super.key,
    required this.controller,
    required this.label,
    this.password = false,
    this.autofillHints,
    this.keyboardType,
    this.helper,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool password;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final String? helper;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  ConsumerState<EmailAuthField> createState() => _EmailAuthFieldState();
}

class _EmailAuthFieldState extends ConsumerState<EmailAuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: widget.password && _hidden,
        autocorrect: !widget.password,
        enableSuggestions: !widget.password,
        autofillHints: widget.autofillHints,
        keyboardType: widget.keyboardType,
        textInputAction: widget.onSubmitted == null
            ? TextInputAction.next
            : TextInputAction.done,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          border: const OutlineInputBorder(),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: AppTranslations.translate(
                    context,
                    ref,
                    _hidden ? 'show_password' : 'hide_password',
                  ),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

class EmailAuthButton extends StatelessWidget {
  const EmailAuthButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class EmailAuthError extends StatelessWidget {
  const EmailAuthError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message!, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}
