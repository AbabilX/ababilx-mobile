import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';

/// One block of a permission page, in the app's own settings style (the
/// privacy-mode and details screens): a label, the rows, an optional muted
/// note — no card, sections separated by a divider.
class PermissionSection extends StatelessWidget {
  const PermissionSection({
    super.key,
    required this.children,
    this.heading,
    this.footer,
    this.divider = true,
  });

  final List<Widget> children;
  final String? heading;
  final String? footer;

  /// Draw the hairline above this section. Off for the first one on a page.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (divider) const Divider(height: 24),
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(heading!, style: theme.textTheme.labelLarge),
          ),
        ...children,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Copy for a refused permission write, from the server's machine code.
String groupPermissionErrorText(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  String fallbackKey = 'group_perm_save_failed',
}) {
  final key = switch (serverErrorCode(error)) {
    'admin_not_restrictable' => 'group_perm_err_admin',
    'tag_restricted' => 'group_perm_err_tag',
    'tag_too_long' => 'group_tag_too_long',
    'not_conversation_manager' => 'group_perm_err_not_admin',
    _ => null,
  };
  if (key == null && isOfflineError(error)) return friendlyErrorMessage(error);
  return AppTranslations.translate(context, ref, key ?? fallbackKey);
}
