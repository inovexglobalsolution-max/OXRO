/// Money helpers. All amounts in this package are integer **paise**
/// (1 rupee = 100 paise). Never use `double` for money.
class Money {
  const Money._();

  static const int paisePerRupee = 100;

  /// Rounds `numerator / denominator` half-up to a whole number.
  /// Half-up means 0.5 always rounds away from zero, matching the
  /// invoice rounding a restaurant owner expects.
  static int roundHalfUpDiv(int numerator, int denominator) {
    if (denominator <= 0) {
      throw ArgumentError.value(
          denominator, 'denominator', 'must be > 0');
    }
    final sign = numerator.isNegative ? -1 : 1;
    final n = numerator.abs();
    final q = (n + denominator ~/ 2) ~/ denominator;
    return sign * q;
  }

  /// Applies a basis-point rate to a paise amount.
  /// 500 bps == 5%. 10000 bps == 100%.
  static int applyBps(int paise, int bps) =>
      roundHalfUpDiv(paise * bps, 10000);

  /// Ceil of `numerator / denominator` for non-negative values.
  static int ceilDiv(int numerator, int denominator) {
    if (denominator <= 0) {
      throw ArgumentError.value(
          denominator, 'denominator', 'must be > 0');
    }
    if (numerator <= 0) return 0;
    return (numerator + denominator - 1) ~/ denominator;
  }

  static int toPaise(num rupees) =>
      (rupees * paisePerRupee).round();

  /// Rupees (may be fractional) from paise.
  static double toRupees(int paise) => paise / paisePerRupee;

  /// Formats paise as INR with Indian digit grouping.
  /// 123450 -> '₹1,234.50'; 123400 -> '₹1,234'; -500 -> '-₹5'.
  static String inr(int paise) {
    final neg = paise < 0;
    final abs = paise.abs();
    final rupees = abs ~/ paisePerRupee;
    final frac = abs % paisePerRupee;
    final grouped = _groupIndian(rupees);
    final body = frac == 0
        ? grouped
        : '$grouped.${frac.toString().padLeft(2, '0')}';
    return '${neg ? '-' : ''}₹$body';
  }

  /// Indian grouping: last 3 digits, then 2-digit groups.
  /// 12345678 -> '1,23,45,678'.
  static String _groupIndian(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var head = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    return '${parts.join(',')},$last3';
  }
}
