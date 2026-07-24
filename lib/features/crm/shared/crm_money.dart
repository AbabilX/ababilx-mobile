import '../data/models/crm_models.dart';

/// Format deal value like web `formatMoney` (BDT → ৳).
String formatCrmMoney(num value, String currency) {
  final n = value.toStringAsFixed(
    value == value.roundToDouble() ? 0 : 2,
  );
  // Simple thousands grouping without intl dep.
  final parts = n.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final formatted =
      parts.length > 1 && parts[1] != '00' ? '$whole.${parts[1]}' : whole;
  if (currency.isEmpty || currency == 'BDT') return '৳$formatted';
  return '$currency $formatted';
}

bool isMineContact(CrmContact c, String myId) {
  if (myId.isEmpty) return false;
  return c.ownerUserId == myId || c.createdBy == myId;
}
