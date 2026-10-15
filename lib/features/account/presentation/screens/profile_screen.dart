import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// Account tab — premium profile header + animated menu.
/// Same callbacks/keys as before; only visuals upgraded.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onWishlist,
    required this.onOrders,
    required this.onAddresses,
    required this.onHelp,
    required this.onSettings,
    required this.onWallet,
    required this.onEdit,
  });

  /// Open wishlist screen (push).
  final VoidCallback onWishlist;

  /// Go to Orders tab.
  final VoidCallback onOrders;

  /// Open addresses screen (push, manage mode).
  final VoidCallback onAddresses;

  /// Open help screen (push).
  final VoidCallback onHelp;

  /// Open settings screen (push).
  final VoidCallback onSettings;

  /// Open wallet screen (push).
  final VoidCallback onWallet;

  /// Open edit-profile screen (push).
  final VoidCallback onEdit;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: CartStore.instance,
          builder: (context, _) => ListView(
          key: const ValueKey('profile_scroll'),
          padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX,
              CartStore.instance.count > 0 ? 96 : 20),
          children: [
            _header(context),
            const SizedBox(height: 14),
            _menuRow(
              context,
              index: 0,
              key: const ValueKey('profile_orders'),
              icon: Icons.local_shipping_outlined,
              gradient: const LinearGradient(colors: [
                Color(0xFF0A8CFF),
                Color(0xFF004E92)
              ]),
              label: 'My Orders',
              sub: 'Track your orders',
              onTap: widget.onOrders,
              trailing: ListenableBuilder(
                listenable: OrderStore.instance,
                builder: (context, _) {
                  final n =
                      OrderStore.instance.active.length;
                  if (n <= 0) return const SizedBox.shrink();
                  return _countPill('$n live',
                      Colors.blue.shade700);
                },
              ),
            ),
            ListenableBuilder(
              listenable: WishlistStore.instance,
              builder: (context, _) {
                final n = WishlistStore.instance.count;
                return _menuRow(
                  context,
                  index: 1,
                  key: const ValueKey('profile_wishlist'),
                  icon: Icons.favorite_outline,
                  gradient: const LinearGradient(colors: [
                    Color(0xFFE91E63),
                    Color(0xFF9C27B0)
                  ]),
                  label: 'My Wishlist',
                  sub: n <= 0
                      ? 'Saved styles'
                      : '$n saved styles',
                  trailing: n <= 0
                      ? null
                      : _countPill('$n', Colors.red),
                  onTap: widget.onWishlist,
                );
              },
            ),
            ListenableBuilder(
              listenable: AddressStore.instance,
              builder: (context, _) {
                final store = AddressStore.instance;
                final n = store.items.length;
                final sub = n <= 0
                    ? 'Add delivery address'
                    : n == 1
                        ? store.displayLine.split('\n').first
                        : '$n saved addresses';
                return _menuRow(
                  context,
                  index: 2,
                  key: const ValueKey('profile_addresses'),
                  icon: Icons.location_on_outlined,
                  gradient: const LinearGradient(colors: [
                    Color(0xFF0E9F6E),
                    Color(0xFF03543F)
                  ]),
                  label: 'Addresses',
                  sub: sub,
                  onTap: widget.onAddresses,
                );
              },
            ),
            ListenableBuilder(
              listenable: WalletStore.instance,
              builder: (context, _) {
                final bal = WalletStore.instance.balance;
                return _menuRow(
                  context,
                  index: 3,
                  key: const ValueKey('profile_wallet'),
                  icon: Icons
                      .account_balance_wallet_outlined,
                  gradient: OxroColors.gradient,
                  label: 'Wallet',
                  sub: bal <= 0
                      ? 'Add money, pay faster'
                      : Product.inr(bal),
                  trailing: bal <= 0
                      ? _countPill('+ Add',
                          OxroColors.primary)
                      : null,
                  onTap: widget.onWallet,
                );
              },
            ),
            _menuRow(
              context,
              index: 4,
              key: const ValueKey('profile_help'),
              icon: Icons.help_outline,
              gradient: const LinearGradient(colors: [
                Color(0xFF8B5CF6),
                Color(0xFF4C1D95)
              ]),
              label: 'Help & Support',
              sub: 'FAQs, contact, orders',
              onTap: widget.onHelp,
            ),
            _menuRow(
              context,
              index: 5,
              key: const ValueKey('profile_settings'),
              icon: Icons.settings_outlined,
              gradient: const LinearGradient(colors: [
                Color(0xFF475569),
                Color(0xFF0F172A)
              ]),
              label: 'Settings',
              sub: 'Notifications, data, about',
              onTap: widget.onSettings,
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) {
                final a = _ambient.value;
                return Container(
                  padding:
                      EdgeInsets.all(context.rs(14)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF082B66),
                        Color(0xFF051D47)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: OxroColors.royalBlue
                            .withValues(alpha: 0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30 +
                            8 *
                                math.sin(
                                    a * math.pi * 2),
                        top: -40,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: OxroColors.primary
                                .withValues(
                                    alpha: 0.25 +
                                        0.06 * a),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -50,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: OxroColors.skyBlue
                                .withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.all(
                                        3),
                                decoration:
                                    BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(
                                              alpha:
                                                  0.6),
                                      width: 2),
                                ),
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  alignment:
                                      Alignment.center,
                                  decoration:
                                      const BoxDecoration(
                                    gradient:
                                        OxroColors.gradient,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 30),
                                ),
                              ),
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape:
                                        BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white,
                                        width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListenableBuilder(
                              listenable:
                                  ProfileStore.instance,
                              builder: (context, _) {
                                final prof =
                                    ProfileStore.instance;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                        prof.displayName,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                            color: Colors
                                                .white)),
                                    const SizedBox(
                                        height: 2),
                                    Text(
                                        prof.isLoggedIn
                                            ? (prof.email ??
                                                '')
                                            : 'Login to see your profile',
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors
                                                .white70)),
                                  ],
                                );
                              },
                            ),
                          ),
                          GestureDetector(
                            key: const ValueKey(
                                'profile_edit'),
                            onTap: widget.onEdit,
                            behavior:
                                HitTestBehavior.opaque,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(
                                        alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(
                                      20),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(
                                          alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 13,
                                    color: Colors.white),
                                SizedBox(width: 4),
                                Text('Edit',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        color:
                                            Colors.white)),
                              ],
                            ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 78),
                        child: Row(
                          children: [
                            Expanded(
                                child: _statChip(
                                    context,
                                    Icons
                                        .local_shipping_outlined,
                                    'Orders',
                                    'Track live')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _statChip(
                                    context,
                                    Icons
                                        .local_offer_outlined,
                                    'OXRO500',
                                    '₹500 off')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _statChip(
                                    context,
                                    Icons
                                        .verified_user_outlined,
                                    'Secure',
                                    'UPI • COD')),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(
      BuildContext context, IconData icon, String t, String s) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countPill(String s, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(s,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: c)),
    );
  }

  Widget _menuRow(
    BuildContext context, {
    required int index,
    Key? key,
    required IconData icon,
    required Gradient gradient,
    required String label,
    required String sub,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: PressScale(
              key: key,
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    EdgeInsets.all(context.rs(12)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                      color: OxroColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: OxroColors.royalBlue
                          .withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(
                                    alpha: 0.15),
                            blurRadius: 8,
                            offset:
                                const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon,
                          size: 21,
                          color: Colors.white),
                    ),
                    SizedBox(width: context.rs(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow
                                  .ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: OxroColors
                                      .charcoal)),
                          Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow
                                  .ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                      OxroColors.muted)),
                        ],
                      ),
                    ),
                    trailing ??
                        const SizedBox.shrink(),
                    const SizedBox(width: 8),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OxroColors.pageBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: OxroColors.border),
                      ),
                      child: const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: OxroColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
