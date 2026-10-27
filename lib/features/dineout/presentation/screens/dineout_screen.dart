import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/filter_chip_row.dart';
import 'package:oxro/features/dineout/data/dineout_repo.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_detail_screen.dart';
import 'package:oxro/features/dineout/presentation/widgets/dineout_card.dart';

class DineoutScreen extends StatefulWidget {
  const DineoutScreen({super.key});

  @override
  State<DineoutScreen> createState() => _DineoutScreenState();
}

class _DineoutScreenState extends State<DineoutScreen> {
  final _search = TextEditingController();
  String _cuisine = 'All';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DineoutRestaurant> get _results =>
      DineoutRepo.filter(cuisine: _cuisine, query: _query);

  void _open(DineoutRestaurant r) {
    pushScreen(context, DineoutDetailScreen(restaurantId: r.id));
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      key: const ValueKey('dineout_screen'),
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const ValueKey('dineout_scroll'),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _hero(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.padX, 14, context.padX, 0),
                child: TextField(
                  key: const ValueKey('dineout_search'),
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search restaurants, cuisines or areas',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: OxroColors.muted,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('dineout_search_clear'),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: OxroColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilterChipRow(
                  key: const ValueKey('dineout_filters'),
                  padding: EdgeInsets.symmetric(horizontal: context.padX),
                  chips: [
                    for (final c in DineoutRepo.cuisines)
                      OxroFilterChip(
                        key: ValueKey('dineout_filter_$c'),
                        label: c,
                        selected: _cuisine == c,
                        onTap: () => setState(() => _cuisine = c),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.padX, 18, context.padX, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cuisine == 'All' ? 'Top tables near you' : _cuisine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(15),
                          fontWeight: FontWeight.w900,
                          color: OxroColors.charcoal,
                        ),
                      ),
                    ),
                    Text(
                      '${results.length} places',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (results.isEmpty)
              SliverToBoxAdapter(child: _empty(context))
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(context.padX, 0, context.padX, 24),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => DineoutCard(
                    restaurant: results[i],
                    onTap: () => _open(results[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.padX, 10, context.padX, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: OxroColors.charcoal,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Dineout',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: context.font(21),
                fontWeight: FontWeight.w900,
                color: OxroColors.charcoal,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: OxroColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  size: 13,
                  color: OxroColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Book a table',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      key: const ValueKey('dineout_hero'),
      margin: EdgeInsets.fromLTRB(context.padX, 8, context.padX, 0),
      padding: EdgeInsets.all(context.rs(18)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OxroColors.navyDark, OxroColors.royalBlue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B051D47),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'UP TO 30% OFF',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  "The city's best tables,\none tap away.",
                  style: TextStyle(
                    fontSize: context.font(19),
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reserve brunch, dinner and everything between.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: context.rs(58),
            height: context.rs(58),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: context.rs(27),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      key: const ValueKey('dineout_empty'),
      padding: EdgeInsets.fromLTRB(context.padX, 36, context.padX, 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OxroColors.pageBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: OxroColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No tables match that search',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: OxroColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try another cuisine or area.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: OxroColors.muted),
          ),
        ],
      ),
    );
  }
}
