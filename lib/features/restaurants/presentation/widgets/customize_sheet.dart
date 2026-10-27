import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/food_image.dart';
import 'package:oxro/app/widgets/product_share.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/detail/data/dish_options.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// What the user picked in the customisation sheet.
class DishSelection {
  const DishSelection({required this.product, required this.qty, this.variant});

  final Product product;
  final int qty;
  final String? variant;
}

Future<DishSelection?> showDishCustomizeSheet(
  BuildContext context,
  Product dish,
) {
  return showModalBottomSheet<DishSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: OxroColors.navyDark.withValues(alpha: 0.45),
    builder: (_) => _CustomizeSheet(dish: dish),
  );
}

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet({required this.dish});

  final Product dish;

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  final _selected = <int, Set<int>>{};
  int _qty = 1;

  List<DishOptionGroup> get _groups => widget.dish.options;

  @override
  void initState() {
    super.initState();
    for (var g = 0; g < _groups.length; g++) {
      final group = _groups[g];
      final picked = <int>{};
      if (!group.multi) {
        final def = group.options.indexWhere((o) => o.defaultOn);
        if (def >= 0) {
          picked.add(def);
        } else if (group.required && group.options.isNotEmpty) {
          picked.add(0);
        }
      }
      _selected[g] = picked;
    }
  }

  int get _extra {
    var extra = 0;
    for (var g = 0; g < _groups.length; g++) {
      for (final i in _selected[g] ?? const <int>{}) {
        extra += _groups[g].options[i].priceDelta;
      }
    }
    return extra;
  }

  String? get _variant {
    final parts = <String>[];
    for (var g = 0; g < _groups.length; g++) {
      final picked = _selected[g] ?? const <int>{};
      for (final i in picked) {
        parts.add(_groups[g].options[i].name);
      }
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  void _tap(int g, int i) {
    final group = _groups[g];
    setState(() {
      final picked = _selected.putIfAbsent(g, () => <int>{});
      if (!group.multi) {
        picked
          ..clear()
          ..add(i);
        return;
      }
      if (picked.contains(i)) {
        picked.remove(i);
        return;
      }
      final max = group.maxSelectable ?? group.options.length;
      if (picked.length < max) picked.add(i);
    });
  }

  void _add() {
    final out = widget.dish.priced(
      widget.dish.price + _extra,
      newMrp: widget.dish.mrp + _extra,
    );
    Navigator.of(
      context,
    ).pop(DishSelection(product: out, qty: _qty, variant: _variant));
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.dish.price + _extra;
    final total = unit * _qty;
    final mrpTotal = (widget.dish.mrp + _extra) * _qty;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.84,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: OxroColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(dish: widget.dish),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  for (var g = 0; g < _groups.length; g++)
                    _GroupCard(
                      key: ValueKey('customize_group_$g'),
                      index: g,
                      dish: widget.dish,
                      group: _groups[g],
                      selected: _selected[g] ?? const <int>{},
                      onTap: (i) => _tap(g, i),
                    ),
                ],
              ),
            ),
            _BottomBar(
              qty: _qty,
              total: total,
              mrpTotal: mrpTotal,
              onMinus: _qty > 1 ? () => setState(() => _qty--) : null,
              onPlus: _qty < 9 ? () => setState(() => _qty++) : null,
              onAdd: _add,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dish});

  final Product dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OxroColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('customize_close'),
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OxroColors.lightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FoodImage(
                    imageUrl: dish.imageUrl,
                    colors: dish.colors,
                    icon: dish.icon,
                    width: 66,
                    height: 66,
                    radius: 14,
                  ),
                  Positioned(
                    left: 3,
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: VegMark(veg: dish.veg, egg: dish.egg, size: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      Product.inr(dish.price),
                      key: const ValueKey('customize_base_price'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: WishlistStore.instance,
                builder: (context, _) {
                  final saved = WishlistStore.instance.contains(dish.id);
                  return _HeaderIcon(
                    key: const ValueKey('customize_bookmark'),
                    icon: saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: saved ? OxroColors.coral : OxroColors.muted,
                    onTap: () => WishlistStore.instance.toggle(dish),
                  );
                },
              ),
              const SizedBox(width: 8),
              _HeaderIcon(
                key: const ValueKey('customize_share'),
                icon: Icons.ios_share_outlined,
                color: OxroColors.muted,
                onTap: () => shareProduct(dish),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: OxroColors.border),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    super.key,
    required this.index,
    required this.dish,
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final Product dish;
  final DishOptionGroup group;
  final Set<int> selected;
  final ValueChanged<int> onTap;

  int get _maxSelect =>
      group.multi ? (group.maxSelectable ?? group.options.length) : 1;

  @override
  Widget build(BuildContext context) {
    final hint =
        'Select up to $_maxSelect ${_maxSelect == 1 ? 'option' : 'options'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: OxroColors.navyDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: OxroColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: OxroColors.border),
            for (var i = 0; i < group.options.length; i++) ...[
              _OptionRow(
                key: ValueKey('customize_${index}_$i'),
                dish: dish,
                option: group.options[i],
                multi: group.multi,
                selected: selected.contains(i),
                onTap: () => onTap(i),
                toggleKey: ValueKey('customize_toggle_${index}_$i'),
              ),
              if (i != group.options.length - 1)
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: OxroColors.border,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.dish,
    required this.option,
    required this.multi,
    required this.selected,
    required this.onTap,
    required this.toggleKey,
  });

  final Product dish;
  final DishOption option;
  final bool multi;
  final bool selected;
  final VoidCallback onTap;
  final Key toggleKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            children: [
              VegMark(veg: dish.veg, egg: dish.egg, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
              if (option.priceDelta > 0) ...[
                const SizedBox(width: 8),
                Text(
                  Product.inr(option.priceDelta),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.charcoal,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              _SelectionMark(
                key: toggleKey,
                multi: multi,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    super.key,
    required this.multi,
    required this.selected,
  });

  final bool multi;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const accent = OxroColors.primary;
    if (multi) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? accent : OxroColors.coral,
            width: 1.6,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : null,
      );
    }
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: selected ? accent : OxroColors.coral,
                width: 1.7,
              ),
            ),
          ),
          if (selected)
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.qty,
    required this.total,
    required this.mrpTotal,
    required this.onMinus,
    required this.onPlus,
    required this.onAdd,
  });

  final int qty;
  final int total;
  final int mrpTotal;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: OxroColors.border)),
        boxShadow: [
          BoxShadow(
            color: OxroColors.navyDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _QtyStepper(
            qty: qty,
            onMinus: onMinus,
            onPlus: onPlus,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('customize_add'),
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OxroColors.orangeTop, OxroColors.orangeBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: OxroColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      qty == 1 ? 'Add item' : 'Add $qty items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Product.inr(total),
                            key: const ValueKey('customize_total'),
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (mrpTotal > total) ...[
                            const SizedBox(width: 6),
                            Text(
                              Product.inr(mrpTotal),
                              style: TextStyle(
                                fontSize: 11,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                                decoration: TextDecoration.lineThrough,
                                decorationColor:
                                    Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('customize_qty_card'),
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OxroColors.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyTap(
            key: const ValueKey('customize_minus'),
            icon: Icons.remove_rounded,
            enabled: onMinus != null,
            onTap: onMinus,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$qty',
              key: const ValueKey('customize_qty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
          ),
          _QtyTap(
            key: const ValueKey('customize_plus'),
            icon: Icons.add_rounded,
            enabled: onPlus != null,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _QtyTap extends StatelessWidget {
  const _QtyTap({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 52,
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? OxroColors.primary
              : OxroColors.muted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
