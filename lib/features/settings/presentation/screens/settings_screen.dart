import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/applock/data/applock_store.dart';
import 'package:oxro/features/applock/presentation/screens/pin_screen.dart';
import 'package:oxro/features/applock/presentation/screens/set_pin_screen.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';
import 'package:oxro/features/search/data/search_repo.dart';
import 'package:oxro/features/settings/data/storage_info.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

/// Settings — premium: gradient hero + animated rows + spring toggles.
/// Same keys/behavior as before; visuals match the Account tab.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;
  bool _offers = true;
  bool _location = true;

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

  /// Yes/No confirm sheet shared by all clear actions.
  /// Returns true only on explicit Yes.
  Future<bool> _confirmClear({
    required String title,
    required String detail,
    required String yesLabel,
  }) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OxroColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal)),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: OxroColors.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey(
                          'clear_confirm_cancel'),
                      onTap: () =>
                          Navigator.of(ctx).pop(false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OxroColors.pageBg,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Text('No, Keep it',
                            style: TextStyle(
                                fontWeight:
                                    FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey(
                          'clear_confirm_go'),
                      onTap: () =>
                          Navigator.of(ctx).pop(true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OxroColors.red,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(yesLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return go == true;
  }

  void _clearDemoData() async {
    final bagN = CartStore.instance.count;
    final wishN = WishlistStore.instance.count;
    if (bagN == 0 && wishN == 0) {
      showOxroSnack(context, 'Nothing to clear');
      return;
    }
    final go = await _confirmClear(
      title: 'Clear bag & wishlist?',
      detail:
          '$bagN item${bagN == 1 ? '' : 's'} in bag • $wishN saved will be removed.',
      yesLabel: 'Yes, Clear',
    );
    if (!go || !mounted) return;
    CartStore.instance.clear();
    WishlistStore.instance.clear();
    showOxroSnack(context, 'Bag & wishlist cleared');
    setState(() {});
  }

  void _clearImages() async {
    final go = await _confirmClear(
      title: 'Clear image cache?',
      detail: 'Images re-download on next view. Safe to clear.',
      yesLabel: 'Yes, Clear',
    );
    if (!go || !mounted) return;
    StorageInfo.clearImageCache();
    showOxroSnack(context, 'Image cache cleared');
    setState(() {});
  }

  void _clearRecents() async {
    if (SearchRepo.recents.isEmpty) {
      showOxroSnack(context, 'No search history');
      return;
    }
    final go = await _confirmClear(
      title: 'Clear search history?',
      detail:
          '${SearchRepo.recents.length} recent search${SearchRepo.recents.length == 1 ? '' : 'es'} will be removed.',
      yesLabel: 'Yes, Clear',
    );
    if (!go || !mounted) return;
    SearchRepo.clearRecents();
    showOxroSnack(context, 'Search history cleared');
    setState(() {});
  }

  Future<void> _logout() async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OxroColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Log out of OXRO?',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.charcoal)),
              const SizedBox(height: 6),
              const Text(
                  'Your bag and wishlist stay on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: OxroColors.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey(
                          'logout_confirm_cancel'),
                      onTap: () =>
                          Navigator.of(ctx).pop(false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OxroColors.pageBg,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontWeight:
                                    FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey(
                          'logout_confirm_go'),
                      onTap: () =>
                          Navigator.of(ctx).pop(true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OxroColors.red,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Text('Log out',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    await ProfileStore.instance.logout();
    if (!mounted) return;
    replaceAllWith(context, const LoginScreen());
  }

  Future<void> _toggleLock() async {
    if (ApplockStore.instance.enabled) {
      await pushScreen(
        context,
        PinScreen(
          title: 'Enter PIN to disable lock',
          onUnlock: () async {
            await ApplockStore.instance.disable();
            if (!mounted) return;
            Navigator.of(context).maybePop();
            showOxroSnack(context, 'App lock off');
            setState(() {});
          },
        ),
      );
      return;
    }
    final set = await pushScreen<bool>(
      context,
      const SetPinScreen(),
    );
    if (!mounted) return;
    if (set == true) {
      showOxroSnack(context, 'App lock on');
      setState(() {});
    }
  }

  /// Staggered fade+slide entrance.
  Widget _in(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8), vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: OxroColors.charcoal),
                  ),
                  const Expanded(
                    child: Text('Settings',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: OxroColors.border),
                    ),
                    child: const Text('v1.0.0',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.muted)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('settings_scroll'),
                padding: EdgeInsets.fromLTRB(
                    context.padX, 6, context.padX, 20),
                children: [
                  _in(0, _hero(context)),
                  _sectionLabel(context, 'Preferences', 1),
                  ListenableBuilder(
                    listenable: NotifStore.instance,
                    builder: (context, _) => _switchRow(
                      context,
                      index: 2,
                      key: const ValueKey('settings_notifs'),
                      icon: Icons.notifications_outlined,
                      gradient: const LinearGradient(colors: [
                        Color(0xFF0A8CFF),
                        Color(0xFF004E92)
                      ]),
                      label: 'Order notifications',
                      sub: 'Tracking + delivery updates',
                      value: NotifStore.instance.enabled,
                      onChanged: (v) =>
                          NotifStore.instance.setEnabled(v),
                    ),
                  ),
                  _switchRow(
                    context,
                    index: 3,
                    key: const ValueKey('settings_offers'),
                    icon: Icons.local_offer_outlined,
                    gradient: const LinearGradient(colors: [
                      Color(0xFFE91E63),
                      Color(0xFF9C27B0)
                    ]),
                    label: 'Offers & deals',
                    sub: 'Sales, coupons, price drops',
                    value: _offers,
                    onChanged: (v) =>
                        setState(() => _offers = v),
                  ),
                  _switchRow(
                    context,
                    index: 4,
                    key: const ValueKey('settings_location'),
                    icon: Icons.location_on_outlined,
                    gradient: const LinearGradient(colors: [
                      Color(0xFF0E9F6E),
                      Color(0xFF03543F)
                    ]),
                    label: 'Location services',
                    sub: 'We deliver across India',
                    value: _location,
                    onChanged: (v) =>
                        setState(() => _location = v),
                  ),
                  _sectionLabel(context, 'Security', 5),
                  ListenableBuilder(
                    listenable: ApplockStore.instance,
                    builder: (context, _) {
                      final on =
                          ApplockStore.instance.enabled;
                      return _in(
                        6,
                        _tapRow(
                          context,
                          key: const ValueKey(
                              'settings_applock'),
                          icon: on
                              ? Icons.lock_outline
                              : Icons.lock_open_outlined,
                          gradient: const LinearGradient(
                              colors: [
                            Color(0xFFD97706),
                            Color(0xFF78350F)
                          ]),
                          label: 'App lock',
                          sub: on
                              ? 'PIN on — tap to turn off'
                              : 'Lock OXRO with a 4-digit PIN',
                          onTap: _toggleLock,
                        ),
                      );
                    },
                  ),
                  _sectionLabel(context, 'Data', 5),
                  _in(
                    6,
                    _tapRow(
                      context,
                      key: const ValueKey('settings_clear'),
                      icon: Icons.delete_outline,
                      gradient: const LinearGradient(colors: [
                        Color(0xFF475569),
                        Color(0xFF0F172A)
                      ]),
                      label: 'Clear bag & wishlist',
                      sub: 'Reset demo data on this device',
                      onTap: _clearDemoData,
                    ),
                  ),
                  _sectionLabel(context, 'Storage', 7),
                  _in(8, _storageCard(context)),
                  _sectionLabel(context, 'About', 7),
                  _in(
                    8,
                    _tapRow(
                      context,
                      key: const ValueKey('settings_terms'),
                      icon: Icons.description_outlined,
                      gradient: OxroColors.gradient,
                      label: 'Terms & Privacy',
                      sub: 'v1.0.0',
                      onTap: () => showOxroSnack(context,
                          'Terms & Privacy coming soon in demo'),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: ProfileStore.instance,
                    builder: (context, _) =>
                        ProfileStore.instance.isLoggedIn
                            ? _in(
                                9,
                                _logoutCard(context),
                              )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, _) {
        final a = _ambient.value;
        return Container(
          padding: EdgeInsets.all(context.rs(14)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF082B66), Color(0xFF051D47)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
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
                    8 * math.sin(a * math.pi * 2),
                top: -40,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: OxroColors.primary.withValues(
                        alpha: 0.25 + 0.06 * a),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.tune,
                      size: 22, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Make OXRO yours',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        SizedBox(height: 2),
                        Text(
                            'Notifications, data, security & storage',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String s, int index) {
    return _in(
      index,
      Padding(
        padding:
            EdgeInsets.fromLTRB(4, context.rs(10), 4, context.rs(8)),
        child: Text(s.toUpperCase(),
            style: TextStyle(
                fontSize: context.font(11.5),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: OxroColors.muted)),
      ),
    );
  }

  Widget _tileIcon(IconData icon, Gradient gradient) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 21, color: Colors.white),
    );
  }

  Widget _switchRow(
    BuildContext context, {
    required int index,
    Key? key,
    required IconData icon,
    required Gradient gradient,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _in(
      index,
      PressScale(
        key: key,
        onTap: () => onChanged(!value),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(context.rs(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OxroColors.border),
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
              _tileIcon(icon, gradient),
              SizedBox(width: context.rs(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.charcoal)),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: OxroColors.muted)),
                  ],
                ),
              ),
              _pillToggle(value: value),
            ],
          ),
        ),
      ),
    );
  }

  /// Spring toggle — whole row taps, knob glides.
  Widget _pillToggle({required bool value}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 52,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: value
            ? OxroColors.gradient
            : const LinearGradient(colors: [
                Color(0xFFE5EBF2),
                Color(0xFFE5EBF2)
              ]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: value
            ? [
                BoxShadow(
                  color: OxroColors.primary
                      .withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        alignment:
            value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x30051D47),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            value ? Icons.check : Icons.close,
            size: 14,
            color: value
                ? OxroColors.primary
                : OxroColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _tapRow(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required Gradient gradient,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return PressScale(
      key: key,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OxroColors.border),
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
            _tileIcon(icon, gradient),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.charcoal)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: OxroColors.muted)),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OxroColors.pageBg,
                shape: BoxShape.circle,
                border:
                    Border.all(color: OxroColors.border),
              ),
              child: const Icon(Icons.chevron_right,
                  size: 16, color: OxroColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageCard(BuildContext context) {
    return FutureBuilder<StorageBreakdown>(
      future: StorageInfo.collect(),
      builder: (context, snap) {
        final b = snap.data;
        final total =
            b == null ? '…' : StorageBreakdown.human(b.totalBytes);
        final frac = b?.fraction ?? 0.0;
        return Container(
          key: const ValueKey('settings_storage'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(context.rs(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OxroColors.border),
            boxShadow: [
              BoxShadow(
                color: OxroColors.royalBlue
                    .withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _tileIcon(
                      Icons.storage_outlined,
                      const LinearGradient(colors: [
                        Color(0xFF0A8CFF),
                        Color(0xFF004E92)
                      ])),
                  SizedBox(width: context.rs(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Using $total of 50 MB',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: OxroColors.charcoal)),
                        Text(
                            b == null
                                ? 'Measuring…'
                                : '${StorageBreakdown.human(b.imageBytes)} images • ${StorageBreakdown.human(b.prefsBytes)} app data',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: OxroColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rs(10)),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 8,
                  backgroundColor: OxroColors.pageBg,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(
                          OxroColors.primary),
                ),
              ),
              if (b != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '${b.cartLines} bag • ${b.wishlistItems} saved • ${b.orderCount} orders • ${b.recentCount} searches',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: OxroColors.muted)),
                ),
              SizedBox(height: context.rs(10)),
              Row(
                children: [
                  Expanded(
                    child: _miniClear(
                      key: const ValueKey(
                          'settings_clear_images'),
                      label: 'Clear images',
                      onTap: _clearImages,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniClear(
                      key: const ValueKey(
                          'settings_clear_recents'),
                      label: 'Clear searches',
                      onTap: _clearRecents,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniClear({
    Key? key,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: OxroColors.pageBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OxroColors.border),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OxroColors.charcoal)),
      ),
    );
  }

  Widget _logoutCard(BuildContext context) {
    return PressScale(
      key: const ValueKey('settings_logout'),
      onTap: _logout,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: OxroColors.red.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: OxroColors.red.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: OxroColors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_outlined,
                  size: 21, color: Colors.white),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text('Log out',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OxroColors.red)),
                  Text(ProfileStore.instance.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: OxroColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
