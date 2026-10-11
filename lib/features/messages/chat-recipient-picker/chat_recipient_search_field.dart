import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The picker's search capsule: a stadium on the same quiet fill as the
/// header pills, Hugeicons at both ends.
class ChatRecipientSearchField extends StatelessWidget {
  const ChatRecipientSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            const SizedBox(width: 16),
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 20,
              color: colors.onSurfaceVariant,
              strokeWidth: 1.6,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            if (controller.text.isEmpty)
              const SizedBox(width: 16)
            else
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: colors.onSurfaceVariant,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
