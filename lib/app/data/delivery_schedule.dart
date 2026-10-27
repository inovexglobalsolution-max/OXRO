/// A delivery slot picked from the schedule sheet.
class DeliverySchedule {
  const DeliverySchedule({
    required this.date,
    required this.dayLabel,
    required this.slot,
  });

  final DateTime date;
  final String dayLabel;
  final String slot;

  String get chipLabel => '$dayLabel · $slot';

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'dayLabel': dayLabel,
    'slot': slot,
  };

  /// Defensive parse for cart caches; malformed values are ignored.
  static DeliverySchedule? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final rawDate = raw['date'];
    final rawDay = raw['dayLabel'];
    final rawSlot = raw['slot'];
    if (rawDate is! String || rawDay is! String || rawSlot is! String) {
      return null;
    }
    final date = DateTime.tryParse(rawDate);
    if (date == null || rawDay.isEmpty || rawSlot.isEmpty) return null;
    return DeliverySchedule(date: date, dayLabel: rawDay, slot: rawSlot);
  }

  @override
  bool operator ==(Object other) =>
      other is DeliverySchedule &&
      _sameDay(other.date, date) &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(date.year, date.month, date.day, slot);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
