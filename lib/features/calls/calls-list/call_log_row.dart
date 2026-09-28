import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/models/call_log_entry.dart';
import 'call_log_format.dart';

/// One history row: who, which way the call went, when, and a redial button.
///
/// [count] is how many calls this row stands for. Signal prints it in front of
/// the state and nowhere else — "(3) Missed · 4:12" — so a stacked row still
/// reads as one event rather than becoming a second kind of row.
///
/// [onCall] is null while the viewer is already in a call — the button stays
/// visible but disabled, same idea as the chat-header call pill.
class CallLogRow extends StatelessWidget {
  const CallLogRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onCall,
    this.onLongPress,
    this.count = 1,
    this.lang = 'en',
  });

  final CallLogEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onCall;

  /// Favourite / open chat, for a 1:1 row; null for a group.
  final VoidCallback? onLongPress;
  final int count;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // A missed call is the one thing worth colouring — everything else is
    // routine history and should read as ordinary text.
    final accent = entry.missed ? scheme.error : scheme.onSurfaceVariant;

    final state = callSubtitle(entry, lang: lang);
    final subtitle = count > 1
        ? AppTranslations.of(
            lang,
            'calls_stacked',
          ).replaceAll('{n}', '$count').replaceAll('{what}', state)
        : state;

    final title = entry.title.isEmpty
        ? AppTranslations.of(lang, 'calls_unknown')
        : entry.title;
    final actionLabel = AppTranslations.of(
      lang,
      entry.isGroup ? 'calls_open' : 'calls_back',
    );

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        minTileHeight: 72,
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        leading: entry.isGroup
            ? ClipOval(
                child: AppAvatar(
                  size: 48,
                  url: entry.avatarUrl,
                  name: title,
                  backgroundColor: scheme.secondaryContainer,
                  fallback: Icon(
                    Icons.groups_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              )
            : AppAvatar(size: 48, url: entry.avatarUrl, name: title),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(
            fontWeight: entry.missed ? FontWeight.w700 : FontWeight.w600,
            color: entry.missed ? scheme.error : scheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Icon(callDirectionIcon(entry), size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: accent),
                ),
              ),
            ],
          ),
        ),
        trailing: Semantics(
          button: true,
          enabled: onCall != null,
          label: actionLabel,
          excludeSemantics: true,
          child: entry.isGroup
              ? IconButton.filledTonal(
                  onPressed: onCall,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: actionLabel,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  style: _actionStyle(scheme),
                )
              // A bare phone glyph says nothing about what it does — the word
              // "Talk" is the tab's own name for a call.
              : TextButton.icon(
                  onPressed: onCall,
                  icon: Icon(
                    entry.isScreenShare
                        ? Icons.screen_share_outlined
                        : entry.isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    size: 20,
                  ),
                  label: Text(AppTranslations.of(lang, 'call_info_talk')),
                  style: _talkStyle(scheme).copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Same neutral square as the details screen's action buttons: the surface
/// tone with an ordinary text colour, so a row's button is quiet and the
/// missed-call red is still the only colour on the row.
ButtonStyle _talkStyle(ColorScheme scheme) => _neutralStyle(scheme).copyWith(
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

ButtonStyle _actionStyle(ColorScheme scheme) => _neutralStyle(scheme).copyWith(
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

ButtonStyle _neutralStyle(ColorScheme scheme) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.onSurface,
  ),
  // Custom colors would otherwise keep the button looking live after
  // onPressed goes null — spell out the disabled look.
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? scheme.onSurface.withValues(alpha: 0.12)
        : scheme.surfaceContainerHigh,
  ),
);
