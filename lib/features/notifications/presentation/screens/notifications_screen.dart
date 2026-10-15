import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';

/// Notifications inbox — Myntra/Flipkart premium:
/// gradient kind icons, unread glow, staggered entrance,
/// swipe-right toggle read, swipe-left delete + Undo.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.onOrders,
    required this.onOffer,
  });

  /// Go to Orders tab (order rows).
  final VoidCallback onOrders;

  /// Open offers/deals (offer rows).
  final VoidCallback onOffer;

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  NotifKind? _filter;
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  /// Gradient identity per kind.
  List<Color> _grad(NotifKind kind) => kind == NotifKind.order
      ? const [Color(0xFF0A8CFF), Color(0xFF004E92)]
      : const [Color(0xFFFF8A00), Color(0xFFFF4D00)];

  void _open(OxroNotif n) {
    NotifStore.instance.markRead(n.id);
    if (n.kind == NotifKind.order) {
      widget.onOrders();
    } else {
      widget.onOffer();
    }
  }

  void _delete(BuildContext context, OxroNotif n) {
    final title = n.title;
    NotifStore.instance.remove(n.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$title dismissed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              NotifStore.instance.restoreLast(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    child: Text('Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                  TextButton(
                    onPressed: () =>
                        NotifStore.instance.markAllRead(),
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.padX),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in [
                      (null, 'All'),
                      (NotifKind.order, 'Orders'),
                      (NotifKind.offer, 'Offers'),
                    ])
                      GestureDetector(
                        key: ValueKey(
                            'notif_chip_${f.$2.toLowerCase()}'),
                        onTap: () =>
                            setState(() => _filter = f.$1),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 200),
                          margin:
                              const EdgeInsets.only(right: 8),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _filter == f.$1
                                ? OxroColors.gradient
                                : null,
                            color: _filter == f.$1
                                ? null
                                : OxroColors.lightGrey,
                            borderRadius:
                                BorderRadius.circular(20),
                            boxShadow: _filter == f.$1
                                ? const [
                                    BoxShadow(
                                      color:
                                          Color(0x30051D47),
                                      blurRadius: 8,
                                      offset:
                                          Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(f.$2,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _filter == f.$1
                                      ? Colors.white
                                      : OxroColors.charcoal)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.rs(10)),
            Expanded(
              child: ListenableBuilder(
                listenable: NotifStore.instance,
                builder: (context, _) {
                  final store = NotifStore.instance;
                  final rows = store.byKind(_filter);
                  if (!store.enabled) {
                    return _premiumState(
                      context,
                      icon: Icons.notifications_off_outlined,
                      title: 'Notifications muted',
                      sub: 'Enable in Settings to get order updates',
                    );
                  }
                  if (rows.isEmpty) {
                    return _premiumState(
                      context,
                      key: const ValueKey('notif_empty'),
                      icon:
                          Icons.mark_email_read_outlined,
                      title: 'All caught up!',
                      sub: 'New orders & offers appear here',
                    );
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(
                        milliseconds: 250),
                    child: ListView(
                      key: const ValueKey('notif_scroll'),
                      padding: EdgeInsets.fromLTRB(
                          context.padX, 2, context.padX, 20),
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _entrance(
                            i,
                            rows.length,
                            Dismissible(
                              key: ValueKey(
                                  'notif_dismiss_${rows[i].id}'),
                              direction: DismissDirection
                                  .horizontal,
                              confirmDismiss: (dir) async {
                                if (dir ==
                                    DismissDirection
                                        .startToEnd) {
                                  store.toggleRead(
                                      rows[i].id);
                                  return false;
                                }
                                return true;
                              },
                              onDismissed: (_) =>
                                  _delete(context, rows[i]),
                              background: Container(
                                margin: EdgeInsets.only(
                                    bottom:
                                        context.rs(10)),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 18),
                                alignment:
                                    Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: Colors.green
                                      .withValues(
                                          alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(
                                          16),
                                ),
                                child: const Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                        Icons
                                            .mark_email_read_outlined,
                                        size: 20,
                                        color:
                                            Colors.green),
                                    SizedBox(width: 8),
                                    Text('Toggle read',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                            color: Colors
                                                .green)),
                                  ],
                                ),
                              ),
                              secondaryBackground:
                                  Container(
                                margin: EdgeInsets.only(
                                    bottom:
                                        context.rs(10)),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 18),
                                alignment:
                                    Alignment.centerRight,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(
                                      alpha: 0.10),
                                  borderRadius:
                                      BorderRadius.circular(
                                          16),
                                ),
                                child: const Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    Text('Delete',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                            color:
                                                Colors.red)),
                                    SizedBox(width: 8),
                                    Icon(
                                        Icons
                                            .delete_outline,
                                        size: 20,
                                        color: Colors.red),
                                  ],
                                ),
                              ),
                              child: _card(
                                  context, rows[i]),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Staggered slide-up + fade entrance (first open only).
  Widget _entrance(int i, int n, Widget child) {
    final start = (i / n) * 0.5;
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((_entry.value - start) / (1 - start))
              .clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _card(BuildContext context, OxroNotif n) {
    final g = _grad(n.kind);
    final glow = g.last;
    final cta = n.kind == NotifKind.order
        ? 'View order >'
        : 'Shop offer >';
    return PressScale(
      scale: 0.97,
      onTap: () => _open(n),
      child: Container(
        key: ValueKey('notif_row_${n.id}'),
        margin: EdgeInsets.only(bottom: context.rs(10)),
        padding: EdgeInsets.all(context.rs(12)),
        decoration: BoxDecoration(
          color: n.unread
              ? OxroColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                n.unread ? glow.withValues(alpha: 0.45) : OxroColors.border,
            width: n.unread ? 1.4 : 1,
          ),
          boxShadow: n.unread
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: g),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(n.icon,
                  size: 22, color: Colors.white),
            ),
            SizedBox(width: context.rs(10)),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2),
                        decoration: BoxDecoration(
                          color: glow.withValues(
                              alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                            n.kind == NotifKind.order
                                ? 'ORDER'
                                : 'OFFER',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: glow)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(n.time,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontSize: 11,
                                color:
                                    OxroColors.muted)),
                      ),
                      if (n.unread) ...[
                        const SizedBox(width: 6),
                        _pulseDot(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal)),
                  const SizedBox(height: 2),
                  Text(n.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: OxroColors.muted)),
                  const SizedBox(height: 6),
                  Text(cta,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: glow)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pulsing unread dot (LIVE-dot pattern reuse).
  Widget _pulseDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: OxroColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _premiumState(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: EdgeInsets.all(context.padX + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: OxroColors.gradient,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30051D47),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon,
                  size: 38, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: OxroColors.muted)),
            const SizedBox(height: 14),
            PressScale(
              onTap: () => showOxroSnack(
                  context, 'Deals — opening soon'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                  color: OxroColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Explore deals',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
