# Plan: Separate Schedule Time into Separate Boxes

## Problem Statement
The user wants to separate the schedule time (day and time) into separate boxes in the UI instead of displaying them combined with a separator like "Today · 6:00 PM - 6:30 PM".

## Current Implementation
- `DeliverySchedule` model (`lib/app/data/delivery_schedule.dart`) combines day and slot via `chipLabel` getter as `'$dayLabel · $slot'`
- Used in 3 places:
  1. **Bag screen** (`lib/features/bag/presentation/screens/bag_screen.dart`) - Per-line schedule chip in cart
  2. **Checkout screen** (`lib/features/checkout/presentation/screens/checkout_screen.dart`) - Scheduled items list
  3. **Home tab** (`lib/features/home/presentation/widgets/food_home_tab.dart`) - Filter chip for scheduling

## Solution
1. Add separate getters to `DeliverySchedule` model: `dayChipLabel` and `timeChipLabel`
2. Update UI components to display day and time in separate containers/boxes (stacked vertically when needed)

## Files to Modify

### 1. `lib/app/data/delivery_schedule.dart`
Add getters:
```dart
String get chipLabel => '$dayLabel · $slot';
String get dayChipLabel => dayLabel;
String get timeChipLabel => slot;
```

### 2. `lib/features/bag/presentation/screens/bag_screen.dart` (_LineScheduleChip)
Stack day and time in separate boxes vertically in a Column inside the Expanded area.

### 3. `lib/features/checkout/presentation/screens/checkout_screen.dart` (_scheduleRow)
Display day and time in separate boxes/containers - stack them vertically in the Column.

### 4. `lib/features/home/presentation/widgets/food_home_tab.dart`
For the filter chip - show both day and time in the label (can be space or separator separated, still in same chip but could format as two tokens; or just append them). The OxroFilterChip takes a String label, so we'll format as `'$dayLabel • $timeChipLabel'` or similar to have them visually distinct.

## Implementation Details

For bag screen `_LineScheduleChip`:
```dart
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? OxroColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(schedule?.dayChipLabel ?? 'Schedule', ...),
      ),
      if (selected && schedule != null) ...[
        SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: OxroColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(schedule.timeChipLabel, ...),
        ),
      ],
    ],
  ),
),
```

For checkout screen:
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(schedule.dayChipLabel, style: TextStyle(fontSize: 10.3, fontWeight: FontWeight.w800, color: _ckAccentDeep)),
    SizedBox(height: 1),
    Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: _ckAccentDeep.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(schedule.timeChipLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _ckAccentDeep)),
    ),
  ],
),
```

For home filter chip:
```dart
label: _schedule == null ? 'Schedule' : '${_schedule!.dayChipLabel} • ${_schedule!.timeChipLabel}',
```

## Validation
- Test in bag screen with scheduled items
- Test in checkout screen  
- Test in home filter
- Ensure styling is consistent with app theme

## Notes
- Keep backward compatibility - `chipLabel` remains for any other usages
- The schedule sheet picker UI doesn't need changes, only the display components
- Using Column with separate containers gives "separate boxes" stacked vertically as requested

