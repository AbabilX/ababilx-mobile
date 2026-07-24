import 'package:flutter/material.dart';

enum ContactScope { mine, all }

/// My / All chips — same FilterChip pattern as wall feed.
class ContactScopeTabs extends StatelessWidget {
  const ContactScopeTabs({
    super.key,
    required this.scope,
    required this.onScope,
    required this.mineCount,
    required this.allCount,
    required this.mineLabel,
    required this.allLabel,
  });

  final ContactScope scope;
  final ValueChanged<ContactScope> onScope;
  final int mineCount;
  final int allCount;
  final String mineLabel;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$mineLabel $mineCount'),
              selected: scope == ContactScope.mine,
              onSelected: (_) => onScope(ContactScope.mine),
              showCheckmark: false,
            ),
          ),
          FilterChip(
            label: Text('$allLabel $allCount'),
            selected: scope == ContactScope.all,
            onSelected: (_) => onScope(ContactScope.all),
            showCheckmark: false,
          ),
        ],
      ),
    );
  }
}
