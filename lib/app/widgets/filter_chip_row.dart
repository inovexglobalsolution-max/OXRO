import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';

class OxroFilterChip extends StatelessWidget {
  const OxroFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
    this.onClear,
    this.trailingIcon,
    this.prominent = false,
    this.badge,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  /// When set on a selected chip, the trailing close icon becomes tappable.
  final VoidCallback? onClear;

  /// Shows a trailing icon while the chip is not selected, e.g. a chevron.
  final IconData? trailingIcon;

  /// Larger reference-style sizing used on the home discovery row.
  final bool prominent;

  /// Optional count badge, e.g. the number of active filters.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Colors.white : OxroColors.muted;
    final showClear = selected && onClear != null;
    final showTrailing = !selected && trailingIcon != null;
    final showBadge = badge != null && badge! > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: prominent ? 40 : 34,
        padding: EdgeInsets.symmetric(horizontal: prominent ? 13 : 12),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(prominent ? 20 : 16),
          border: Border.all(
            color: selected ? Colors.black : OxroColors.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: prominent ? 15 : 14, color: accent),
              SizedBox(width: prominent ? 6 : 5),
            ],
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: prominent ? 13.5 : 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : OxroColors.charcoal,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: OxroColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            if (showTrailing) ...[
              const SizedBox(width: 2),
              Icon(trailingIcon, size: prominent ? 18 : 16, color: accent),
            ],
            if (selected && !showClear) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: prominent ? 14 : 12, color: accent),
            ],
            if (showClear)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.close,
                    size: prominent ? 15 : 12,
                    color: accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class OxroResetChip extends StatelessWidget {
  const OxroResetChip({super.key, required this.onTap, this.prominent = false});

  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: prominent ? 40 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Text(
          'Reset',
          style: TextStyle(
            fontSize: prominent ? 13.5 : 12,
            fontWeight: FontWeight.w800,
            color: OxroColors.coral,
          ),
        ),
      ),
    );
  }
}

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({super.key, required this.chips, this.padding});

  final List<Widget> chips;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }
}
