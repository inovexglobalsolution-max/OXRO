import 'package:flutter/material.dart';

import 'package:oxro/app/data/delivery_schedule.dart';
import 'package:oxro/app/theme/app_colors.dart';

export 'package:oxro/app/data/delivery_schedule.dart';

/// Reference-style date and time picker for scheduled delivery.
Future<DeliverySchedule?> showScheduleSheet(
  BuildContext context, {
  DeliverySchedule? initial,
}) {
  return showModalBottomSheet<DeliverySchedule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      return SizedBox(
        height: (height * 0.62).clamp(430.0, 640.0),
        child: Material(
          key: const ValueKey('schedule_sheet'),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: _ScheduleBody(initial: initial),
        ),
      );
    },
  );
}

class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody({this.initial});

  final DeliverySchedule? initial;

  @override
  State<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends State<_ScheduleBody> {
  late final List<_ScheduleDay> _days;
  late int _dayIndex;
  int? _slotIndex;

  @override
  void initState() {
    super.initState();
    _days = _buildDays(DateTime.now());
    _restoreSelection();
  }

  void _restoreSelection() {
    final initial = widget.initial;
    if (initial != null) {
      final dayIndex = _days.indexWhere(
        (day) => _sameDay(day.date, initial.date),
      );
      if (dayIndex >= 0) {
        final slotIndex = _days[dayIndex].slots.indexWhere(
          (slot) => slot.enabled && slot.label == initial.slot,
        );
        if (slotIndex >= 0) {
          _dayIndex = dayIndex;
          _slotIndex = slotIndex;
          return;
        }
      }
    }
    _dayIndex = 0;
    _slotIndex = _firstEnabledSlot(0);
    if (_slotIndex == null) {
      for (var i = 1; i < _days.length; i++) {
        final index = _firstEnabledSlot(i);
        if (index != null) {
          _dayIndex = i;
          _slotIndex = index;
          break;
        }
      }
    }
  }

  int? _firstEnabledSlot(int dayIndex) {
    final slots = _days[dayIndex].slots;
    final index = slots.indexWhere((slot) => slot.enabled);
    return index < 0 ? null : index;
  }

  void _selectDay(int index) {
    setState(() {
      _dayIndex = index;
      _slotIndex = _firstEnabledSlot(index);
    });
  }

  void _confirm() {
    final slotIndex = _slotIndex;
    if (slotIndex == null) return;
    final day = _days[_dayIndex];
    Navigator.of(context).pop(
      DeliverySchedule(
        date: day.date,
        dayLabel: day.caption,
        slot: day.slots[slotIndex].label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _days[_dayIndex];
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select your delivery time',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Material(
                  color: const Color(0xFF3D3D3D),
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('schedule_close'),
                    onTap: () => Navigator.of(context).maybePop(),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _days.length; i++)
                Expanded(
                  child: _DateTab(
                    key: ValueKey('schedule_date_$i'),
                    title: _days[i].title,
                    caption: _days[i].caption,
                    selected: i == _dayIndex,
                    onTap: () => _selectDay(i),
                  ),
                ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: OxroColors.border),
          Expanded(
            child: ListView.separated(
              key: const ValueKey('schedule_slots'),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
              itemCount: day.slots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final slot = day.slots[i];
                final selected = i == _slotIndex;
                return _SlotTile(
                  key: ValueKey('schedule_slot_$i'),
                  label: slot.label,
                  selected: selected,
                  enabled: slot.enabled,
                  onTap: slot.enabled
                      ? () => setState(() => _slotIndex = i)
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('schedule_confirm'),
                onPressed: _slotIndex == null ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: OxroColors.coral,
                  disabledBackgroundColor: OxroColors.border,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTab extends StatelessWidget {
  const _DateTab({
    super.key,
    required this.title,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? OxroColors.charcoal : OxroColors.muted;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? OxroColors.coral : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? OxroColors.muted
                      : OxroColors.muted.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? OxroColors.muted.withValues(alpha: 0.34)
        : selected
        ? OxroColors.charcoal
        : OxroColors.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1F4F8) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ScheduleDay {
  const _ScheduleDay({
    required this.date,
    required this.title,
    required this.caption,
    required this.slots,
  });

  final DateTime date;
  final String title;
  final String caption;
  final List<_SlotOption> slots;
}

class _SlotOption {
  const _SlotOption({required this.label, required this.enabled});

  final String label;
  final bool enabled;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _slotStarts = [
  18 * 60,
  18 * 60 + 30,
  19 * 60,
  19 * 60 + 30,
  20 * 60,
  20 * 60 + 30,
  21 * 60,
  21 * 60 + 30,
];

List<_ScheduleDay> _buildDays(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 0; i < 3; i++)
      () {
        final date = today.add(Duration(days: i));
        return _ScheduleDay(
          date: date,
          title: '${date.day} ${_months[date.month - 1]}',
          caption: i == 0
              ? 'Today'
              : i == 1
              ? 'Tomorrow'
              : _weekdays[date.weekday - 1],
          slots: _slotsFor(date, now),
        );
      }(),
  ];
}

List<_SlotOption> _slotsFor(DateTime date, DateTime now) {
  final isToday = _sameDay(date, now);
  final nowMinutes = now.hour * 60 + now.minute;
  return [
    for (final start in _slotStarts)
      _SlotOption(
        label: _slotLabel(start, start + 30),
        enabled: !isToday || start > nowMinutes,
      ),
  ];
}

String _slotLabel(int start, int end) {
  final startPeriod = start >= 12 * 60 ? 'PM' : 'AM';
  final endPeriod = end >= 12 * 60 ? 'PM' : 'AM';
  final samePeriod = startPeriod == endPeriod;
  final left = _clock(start, includePeriod: !samePeriod, period: startPeriod);
  final right = _clock(end, includePeriod: true, period: endPeriod);
  return '$left – $right';
}

String _clock(
  int minutes, {
  required bool includePeriod,
  required String period,
}) {
  final hour24 = minutes ~/ 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = minutes % 60;
  final base = minute == 0
      ? '$hour'
      : '$hour:${minute.toString().padLeft(2, '0')}';
  return includePeriod ? '$base $period' : base;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
