/// `৳12,500` or `৳12,500.50`; [fixed] always shows two decimals (`৳500.00`),
/// which is how the amount reads on the pay sheet and the reveal.
String formatTaka(num value, {bool fixed = false}) {
  final whole = value == value.roundToDouble();
  final n = value.toStringAsFixed(fixed || !whole ? 2 : 0);
  final parts = n.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length > 1 ? '৳$grouped.${parts[1]}' : '৳$grouped';
}

/// The most one JPack may carry. A demo ceiling, so a typo cannot empty the
/// balance in one tap.
const jpackMaxAmount = 50000.0;
