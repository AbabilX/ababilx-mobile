import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Web `MetaCopyBadges` — tap badge to copy value.
class MetaCopyBadges extends StatelessWidget {
  const MetaCopyBadges({
    super.key,
    this.company,
    this.email,
    this.phone,
    this.source,
  });

  final String? company;
  final String? email;
  final String? phone;
  final String? source;

  List<({String key, String label, String value})> get _bits {
    final bits = <({String key, String label, String value})>[];
    final c = (company ?? '').trim();
    final e = (email ?? '').trim();
    final p = (phone ?? '').trim();
    final s = (source ?? '').trim();
    if (c.isNotEmpty) bits.add((key: 'company', label: c, value: c));
    if (e.isNotEmpty) bits.add((key: 'email', label: e, value: e));
    if (p.isNotEmpty) bits.add((key: 'phone', label: p, value: p));
    if (s.isNotEmpty) {
      bits.add((key: 'source', label: 'Source: $s', value: s));
    }
    return bits;
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied “$value”')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bits = _bits;
    if (bits.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final bit in bits)
          Material(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => _copy(context, bit.value),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  bit.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
