import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:latlong2/latlong.dart' as latlng;
import 'package:oxro/app/data/food_media.dart';
import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/app/repositories/order_repo.dart';
import 'package:oxro/app/routing/directions_client.dart';
import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_pricing.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/order_chat_screen.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/premium/presentation/screens/premium_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';

const _headerGreen = Color(0xFF15803D);
const _headerGreenSoft = Color(0xFF166534);

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final String orderId;

  /// Test seam — replaces the network+realtime flow with a fixed payload
  /// so widget tests stay deterministic offline.
  @visibleForTesting
  static LiveTracking? debugTrackingOverride;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final _repo = OrderRepo();
  final _directions = DirectionsClient();
  final _scroll = ScrollController();

  GoogleMapController? _mapController;
  Timer? _poll;
  LiveTracking? _live;
  List<latlng.LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  int? _routeDurationMin;
  latlng.LatLng? _displayedPartner;

  bool _loading = true;
  String? _trackingError;

  int _lastRouteLatE6 = 0;
  int _lastRouteLngE6 = 0;

  final _customInstructionController = TextEditingController();
  final ValueNotifier<double> _collapse = ValueNotifier(0);
  late final AnimationController _ambient;
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scroll.addListener(_onScroll);
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refreshLive());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshLive(force: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _customInstructionController.dispose();
    _ambient.dispose();
    _entry.dispose();
    _mapController?.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final t = (_scroll.offset / 72).clamp(0.0, 1.0);
    if ((_collapse.value - t).abs() > 0.01) _collapse.value = t;
  }

  Future<void> _refreshLive({bool force = false}) async {
    final override = TrackingScreen.debugTrackingOverride;
    if (override != null) {
      if (mounted) {
        setState(() {
          _live = override;
          _loading = false;
        });
      }
      return;
    }
    if (!CustomerIdentity.networkEnabled) {
      // Widget tests run offline — no network, render the store order.
      if (mounted) setState(() => _loading = false);
      return;
    }
    final live = await _repo.fetchLiveTracking(widget.orderId);
    if (!mounted) return;
    if (live == null) {
      setState(() {
        _loading = false;
        _trackingError = 'Live tracking unavailable — check your connection';
      });
      return;
    }
    final prevPartner = _live?.partnerLat != null && _live?.partnerLng != null
        ? latlng.LatLng(_live!.partnerLat!, _live!.partnerLng!)
        : null;
    setState(() {
      _live = live;
      _loading = false;
      _trackingError = null;
    });
    final newPartner = live.partnerLat != null && live.partnerLng != null
        ? latlng.LatLng(live.partnerLat!, live.partnerLng!)
        : null;
    if (newPartner != null) {
      _animatePartnerMarkerTo(newPartner, prevPartner);
      _maybeRefreshRoute(newPartner, live);
    }
  }

  void _animatePartnerMarkerTo(latlng.LatLng target, latlng.LatLng? from) {
    if (from == null ||
        (from.latitude == target.latitude &&
            from.longitude == target.longitude)) {
      setState(() => _displayedPartner = target);
      return;
    }
    final start = _displayedPartner ?? from;
    _displayedPartner = target;

    // Cheap tween: step through 8 interpolated positions for smooth movement.
    const steps = 8;
    var i = 0;
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      i += 1;
      final t = (i / steps).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(t);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _displayedPartner = latlng.LatLng(
          start.latitude + (target.latitude - start.latitude) * eased,
          start.longitude + (target.longitude - start.longitude) * eased,
        );
      });
      if (i >= steps) timer.cancel();
    });
  }

  Future<void> _maybeRefreshRoute(
    latlng.LatLng partner,
    LiveTracking live,
  ) async {
    final customerLat = live.customerLat;
    final customerLng = live.customerLng;
    if (customerLat == null || customerLng == null) return;
    final latE6 = (partner.latitude * 1e6).round();
    final lngE6 = (partner.longitude * 1e6).round();
    final canRefresh =
        _routePoints.isEmpty ||
        (latE6 - _lastRouteLatE6).abs() >= 800 ||
        (lngE6 - _lastRouteLngE6).abs() >= 800;
    if (!canRefresh) return;
    _lastRouteLatE6 = latE6;
    _lastRouteLngE6 = lngE6;
    final customer = latlng.LatLng(customerLat, customerLng);
    final route = await _directions.route(partner, customer);
    if (!mounted || route == null) return;
    setState(() {
      _routePoints = route.points;
      _routeDistanceKm = route.distanceKm;
      _routeDurationMin = route.durationMinutes;
    });
  }

  // ─── helpers ────────────────────────────────────────────────

  static int _doneCount(OrderStatus status) => switch (status) {
    OrderStatus.processing => 1,
    OrderStatus.shipped => 3,
    OrderStatus.outForDelivery => 4,
    OrderStatus.delivered => 5,
    OrderStatus.cancelled => 1,
  };

  static String _headline(OrderStatus status) => switch (status) {
    OrderStatus.processing => 'Order confirmed',
    OrderStatus.shipped => 'Being Prepared',
    OrderStatus.outForDelivery => 'On the way',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };

  static String _statusPill(OrderStatus status) => switch (status) {
    OrderStatus.delivered => 'COMPLETED',
    OrderStatus.cancelled => 'CLOSED',
    _ => 'ON-TIME',
  };

  static String _addressLine(Address? address) {
    if (address == null) return 'Add a delivery address';
    return '${address.line}, ${address.city} — ${address.pin}';
  }

  static String? _savingsText(OrderBill? bill) {
    if (bill == null) return null;
    if (bill.discountPaise > 0) {
      return '${Money.inr(bill.discountPaise)} saved on this order';
    }
    if (bill.deliveryPaise == 0) return 'Free delivery applied on this order';
    return null;
  }

  static String _paymentLabel(String? s) => switch (s) {
    'paid' => 'Paid',
    'pending' => 'Pending',
    _ => 'Pending',
  };

  int _etaMinutes() {
    final live = _live;
    if (live != null && live.estimatedArrivalMinutes > 0) {
      return live.estimatedArrivalMinutes;
    }
    final st = OrderStore.instance.statusOf(widget.orderId);
    final order = OrderStore.instance.byId(widget.orderId);
    final kitchen = order?.restaurantId == null
        ? null
        : RestaurantRepo.byId(order!.restaurantId!);
    final base = kitchen?.etaMinutes ?? 30;
    return st == OrderStatus.outForDelivery ? 12 : base;
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: widget.orderId));
    showOxroSnack(context, 'Order ID copied');
  }

  Future<void> _shareOrder() async {
    final id = widget.orderId;
    await SharePlus.instance.share(
      ShareParams(text: 'Track my OXRO order $id — I ordered from OXRO.'),
    );
  }

  Future<void> _openHelp() async {
    pushScreen(context, HelpScreen(orderId: widget.orderId));
  }

  void _openRestaurant(String? id) {
    if (id == null || id.isEmpty || RestaurantRepo.byId(id) == null) return;
    pushScreen(context, RestaurantScreen(restaurantId: id));
  }

  void _openOrderDetails() {
    pushScreen(context, OrderDetailsScreen(orderId: widget.orderId));
  }

  void _openChat() {
    final name = _live?.partnerName;
    pushScreen(
      context,
      OrderChatScreen(orderId: widget.orderId, partnerName: name),
    );
  }

  Future<void> _callPartner() async {
    final phone = _live?.partnerPhone?.trim();
    if (phone == null || phone.isEmpty) {
      showOxroSnack(context, 'Delivery partner number not available yet');
      return;
    }
    final normalized = phone.startsWith('+') ? phone : '+91$phone';
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showOxroSnack(context, 'Could not place the call');
  }

  void _toggleInstructions() {
    setState(() => _instructionsOpen = !_instructionsOpen);
  }

  bool _instructionsOpen = false;

  Widget _in(double start, Widget child) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((_entry.value - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  // ─── screen ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final store = OrderStore.instance;
    final order = store.byId(widget.orderId);
    final status = store.statusOf(widget.orderId);
    final steps = store.trackingSteps(widget.orderId);
    final done = _doneCount(status);
    final kitchenId = order?.restaurantId;
    final kitchenName = order?.kitchenName;
    final restaurant = kitchenId == null
        ? null
        : RestaurantRepo.byId(kitchenId);
    final address = AddressStore.instance.address;
    final eta = _etaMinutes();
    final progress = status == OrderStatus.cancelled
        ? 0.18
        : (done / 5).clamp(0.0, 1.0);
    final payable =
        order?.payablePaise ??
        (order == null
            ? 0
            : order.products.fold<int>(0, (s, p) => s + p.price) * 100);
    final itemCount = order?.products.length ?? 0;
    final firstItem = order?.products.isNotEmpty == true
        ? order!.products.first.name
        : 'Order items';
    final savings = _savingsText(order?.bill);
    final accent = status == OrderStatus.cancelled
        ? OxroColors.red
        : OxroColors.green;
    final headerHeight = context.rs(76);
    final live = _live;

    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              key: const ValueKey('track_screen'),
              controller: _scroll,
              padding: EdgeInsets.only(top: headerHeight + 6, bottom: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.maxContentW),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.padX),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _in(
                          0,
                          _mapCard(
                            context,
                            status: status,
                            eta: eta,
                            live: live,
                            orderId: widget.orderId,
                          ),
                        ),
                        SizedBox(height: context.rs(12)),
                        _in(
                          0.1,
                          _partnerCard(context, status: status, live: live),
                        ),
                        SizedBox(height: context.rs(12)),
                        _in(0.18, _deliveryInstructionsCard(context, status)),
                        SizedBox(height: context.rs(12)),
                        if (live?.guaranteeEligible == true) ...[
                          _in(0.24, _arrivalGuaranteeCard(live!)),
                          SizedBox(height: context.rs(12)),
                        ],
                        _in(
                          0.26,
                          _progressTracker(
                            context,
                            status,
                            steps,
                            done,
                            accent,
                          ),
                        ),
                        SizedBox(height: context.rs(12)),
                        _in(
                          0.32,
                          _trackRow(
                            context,
                            key: const ValueKey('track_address'),
                            icon: Icons.location_on_outlined,
                            iconColor: OxroColors.royalBlue,
                            title: 'Delivering to ${address?.label ?? 'Home'}',
                            subtitle: _addressLine(address),
                          ),
                        ),
                        const _DashedDivider(),
                        _in(
                          0.4,
                          _orderSummaryRow(
                            context,
                            payable: payable,
                            itemCount: itemCount,
                            firstItem: firstItem,
                            statusPill: _statusPill(status),
                            savings: savings,
                            paymentStatus: _paymentLabel(order?.paymentStatus),
                          ),
                        ),
                        if (savings != null) ...[
                          SizedBox(height: context.rs(8)),
                          _savingsTile(savings),
                        ],
                        const _DashedDivider(),
                        _in(
                          0.46,
                          _restaurantRow(
                            context,
                            kitchenId: kitchenId,
                            kitchenName: kitchenName,
                            restaurant: restaurant,
                          ),
                        ),
                        const _DashedDivider(),
                        _in(0.52, _helpSupportRow(context)),
                        SizedBox(height: context.rs(14)),
                        _in(0.58, _promoSection(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _header(
                context,
                status: status,
                eta: eta,
                progress: progress,
                accent: accent,
                kitchenName: kitchenName ?? 'OXRO Kitchen',
                height: headerHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── header ────────────────────────────────────────────────

  Widget _header(
    BuildContext context, {
    required OrderStatus status,
    required int eta,
    required double progress,
    required Color accent,
    required String kitchenName,
    required double height,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _collapse,
      builder: (context, t, _) {
        final active =
            status != OrderStatus.delivered && status != OrderStatus.cancelled;
        final statusLine = active
            ? '$eta Mins left • ${_headline(status)}'
            : _headline(status);
        return Container(
          key: const ValueKey('track_header'),
          height: height,
          decoration: const BoxDecoration(
            color: _headerGreen,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_headerGreen, _headerGreenSoft],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.maxContentW + context.padX * 2,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: context.rs(2),
                        right: context.padX,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            key: const ValueKey('track_back'),
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kitchenName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: context.font(13),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Always-visible status line (header headline).
                                if (t <= 0.02)
                                  Text(
                                    statusLine,
                                    key: const ValueKey('track_status_visible'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: context.font(16.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                if (t > 0.02)
                                  Text(
                                    statusLine,
                                    key: const ValueKey('track_status'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: context.font(12),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _headerIcon(
                            key: const ValueKey('track_refresh'),
                            tooltip: 'Refresh tracking',
                            icon: _loading
                                ? Icons.sync_rounded
                                : Icons.refresh_rounded,
                            onTap: () => _refreshLive(force: true),
                          ),
                          SizedBox(width: context.rs(4)),
                          _headerIcon(
                            key: const ValueKey('track_share'),
                            tooltip: 'Share order',
                            icon: Icons.share_outlined,
                            onTap: _shareOrder,
                          ),
                          SizedBox(width: context.rs(4)),
                          _headerIcon(
                            key: const ValueKey('track_copy'),
                            tooltip: 'Copy order id',
                            icon: Icons.copy_rounded,
                            onTap: _copyId,
                          ),
                          SizedBox(width: context.rs(6)),
                          TextButton(
                            key: const ValueKey('track_help'),
                            onPressed: _openHelp,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.16,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text(
                              'Help',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: (0.4 + 0.6 * t).clamp(0.0, 1.0),
                    child: LinearProgressIndicator(
                      key: const ValueKey('track_header_progress'),
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        status == OrderStatus.outForDelivery
                            ? const Color(0xFFFFF7CC)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerIcon({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
    );
  }

  // ─── map ───────────────────────────────────────────────────

  Widget _mapCard(
    BuildContext context, {
    required OrderStatus status,
    required int eta,
    required LiveTracking? live,
    required String orderId,
  }) {
    return Container(
      key: const ValueKey('track_map_card'),
      height: context.rs(210),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OxroColors.border),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: OxroColors.charcoal.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!CustomerIdentity.networkEnabled)
            _mapOfflineFallback()
          else
            _googleMap(status: status, eta: eta, live: live),
          // ETA pill overlay
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_bike_rounded,
                    size: 14,
                    color: _headerGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _etaPillText(status, eta, live),
                    key: const ValueKey('track_eta_pill'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: _headerGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_trackingError != null)
            Positioned(
              left: 10,
              top: 44,
              right: 10,
              child: Container(
                key: const ValueKey('track_tracking_error'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(
                  _trackingError!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ),
            ),
          // Recenter button
          Positioned(
            right: 10,
            bottom: 12,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                key: const ValueKey('track_recenter'),
                customBorder: const CircleBorder(),
                onTap: _recenterCamera,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    size: 18,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _etaPillText(OrderStatus status, int eta, LiveTracking? live) {
    if (status == OrderStatus.delivered) return 'Delivered';
    if (status == OrderStatus.cancelled) return 'Cancelled';
    if (_routeDistanceKm != null && _routeDurationMin != null) {
      return '${_routeDistanceKm!.toStringAsFixed(1)} km • $_routeDurationMin min';
    }
    if (_routeDistanceKm != null) {
      return '${_routeDistanceKm!.toStringAsFixed(1)} km away';
    }
    return '$eta min ETA';
  }

  Widget _googleMap({
    required OrderStatus status,
    required int eta,
    required LiveTracking? live,
  }) {
    final customerLat =
        live?.customerLat ?? AddressStore.instance.address?.latitude;
    final customerLng =
        live?.customerLng ?? AddressStore.instance.address?.longitude;
    if (customerLat == null || customerLng == null) {
      return _mapOfflineFallback();
    }
    final customer = LatLng(customerLat, customerLng);
    final displayed = _displayedPartner;
    final partnerLat = live?.partnerLat;
    final partnerLng = live?.partnerLng;
    final LatLng? partner = displayed != null
        ? LatLng(displayed.latitude, displayed.longitude)
        : (partnerLat != null && partnerLng != null
              ? LatLng(partnerLat, partnerLng)
              : null);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('customer_destination'),
        position: customer,
        infoWindow: const InfoWindow(title: 'Delivery address'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      if (partner != null)
        Marker(
          markerId: const MarkerId('delivery_partner'),
          position: partner,
          infoWindow: InfoWindow(
            title: live?.partnerName ?? 'Delivery partner',
            snippet: _routeDistanceKm != null
                ? '${_routeDistanceKm!.toStringAsFixed(1)} km away'
                : 'En route',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: customer, zoom: 13),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCamera(customer, partner);
      },
      markers: markers,
      polylines: _routePoints.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('delivery_route'),
                color: const Color(0xFF4285F4),
                width: 5,
                points: _routePoints
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
              ),
            }
          : const {},
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: false,
    );
  }

  Widget _mapOfflineFallback() {
    return Container(
      key: const ValueKey('track_map_unavailable'),
      color: const Color(0xFFEAEFF5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: context.rs(46),
            color: OxroColors.muted,
          ),
          const SizedBox(height: 8),
          Text(
            'Map unavailable offline',
            key: const ValueKey('track_map_offline'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: OxroColors.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Connect to load the live map',
            style: TextStyle(fontSize: 11, color: OxroColors.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _fitCamera(LatLng customer, LatLng? partner) async {
    if (partner == null) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: customer, zoom: 13),
        ),
      );
      return;
    }
    final bounds = _boundsFor([customer, partner]);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 72),
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _recenterCamera() async {
    if (_mapController == null) return;
    final live = _live;
    final customer = AddressStore.instance.address;
    final lat = live?.customerLat ?? customer?.latitude;
    final lng = live?.customerLng ?? customer?.longitude;
    if (lat == null || lng == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
    );
  }

  // ─── partner ────────────────────────────────────────────────

  Widget _partnerCard(
    BuildContext context, {
    required OrderStatus status,
    required LiveTracking? live,
  }) {
    final partnerName = live?.partnerName?.trim();
    final hasPartner = partnerName != null && partnerName.isNotEmpty;
    return Container(
      key: const ValueKey('track_partner_card'),
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OxroColors.border),
        boxShadow: [
          BoxShadow(
            color: OxroColors.charcoal.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _partnerAvatar(live),
              SizedBox(width: context.rs(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPartner) ...[
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partnerName,
                              key: const ValueKey('track_partner_name'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.font(15),
                                fontWeight: FontWeight.w900,
                                color: OxroColors.charcoal,
                              ),
                            ),
                          ),
                          if (live?.partnerVerified == true) ...[
                            SizedBox(width: context.rs(4)),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: OxroColors.green,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: OxroColors.gold,
                          ),
                          Text(
                            ' ${live?.partnerRating?.toStringAsFixed(1) ?? '4.8'} • ',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: OxroColors.charcoal,
                            ),
                          ),
                          Text(
                            '${live?.partnerCompletedDeliveries ?? 0} deliveries',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: OxroColors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (live?.partnerVehicleType != null)
                        Text(
                          '${live!.partnerVehicleType}${live.partnerVehicleNumber == null ? '' : ' • ${live.partnerVehicleNumber}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: OxroColors.muted,
                          ),
                        ),
                    ] else ...[
                      Text(
                        status == OrderStatus.delivered ||
                                status == OrderStatus.cancelled
                            ? 'Delivery complete'
                            : 'Finding your delivery partner',
                        key: const ValueKey('track_partner_pending'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(13.5),
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'A partner will be assigned shortly',
                        style: TextStyle(fontSize: 12, color: OxroColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              _callChatButtons(live),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerAvatar(LiveTracking? live) {
    final name = live?.partnerName?.trim();
    final initials = (name == null || name.isEmpty)
        ? '?'
        : name
              .split(' ')
              .where((p) => p.isNotEmpty)
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();
    final url = live?.partnerPhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        key: const ValueKey('track_partner_photo'),
        radius: 26,
        backgroundImage: NetworkImage(url),
        backgroundColor: OxroColors.pageBg,
        child: const SizedBox.shrink(),
      );
    }
    return CircleAvatar(
      key: const ValueKey('track_partner_avatar'),
      radius: 26,
      backgroundColor: _headerGreen,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _callChatButtons(LiveTracking? live) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('track_partner_call'),
          tooltip: 'Call partner',
          onPressed: _callPartner,
          icon: const Icon(
            Icons.call_rounded,
            color: OxroColors.green,
            size: 22,
          ),
        ),
        IconButton(
          key: const ValueKey('track_partner_chat'),
          tooltip: 'Chat with partner',
          onPressed: _openChat,
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: OxroColors.authBlue,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ─── delivery instructions ─────────────────────────────────

  static const _instructionChips = [
    'Leave at door',
    'Hand it to me',
    'Leave with security',
    'Call before delivery',
    "Don't ring the bell",
  ];

  Widget _deliveryInstructionsCard(BuildContext context, OrderStatus status) {
    final locked =
        status == OrderStatus.delivered || status == OrderStatus.cancelled;
    final live = _live;
    final saved = live?.deliveryInstructions?.trim();

    return Container(
      key: const ValueKey('track_instructions_card'),
      padding: EdgeInsets.fromLTRB(
        context.rs(14),
        context.rs(12),
        context.rs(14),
        context.rs(10),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 18,
                color: OxroColors.royalBlue,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Delivery instructions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
              if (locked && saved != null && saved.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: OxroColors.pageBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Locked after pickup',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: OxroColors.muted,
                    ),
                  ),
                ),
              IconButton(
                key: const ValueKey('track_instructions_toggle'),
                onPressed: _toggleInstructions,
                icon: Icon(
                  _instructionsOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: OxroColors.muted,
                ),
              ),
            ],
          ),
          if (!_instructionsOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                saved == null || saved.isEmpty
                    ? 'Add instructions for the delivery partner'
                    : saved,
                key: const ValueKey('track_instructions_preview'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: OxroColors.muted),
              ),
            ),
          AnimatedCrossFade(
            crossFadeState: _instructionsOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
            firstChild: const SizedBox(height: 4),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _instructionChips
                      .map(
                        (chip) => _InstructionChip(
                          label: chip,
                          onTap: locked ? null : () => _saveInstruction(chip),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('track_custom_instruction'),
                  controller: _customInstructionController,
                  enabled: !locked,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: locked
                      ? null
                      : (_) =>
                            _saveInstruction(_customInstructionController.text),
                  decoration: InputDecoration(
                    hintText: 'Custom instruction (e.g. gate code 1234)',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: OxroColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('track_save_instruction'),
                      onPressed: locked
                          ? null
                          : () => _saveInstruction(
                              _customInstructionController.text,
                            ),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInstruction(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (!CustomerIdentity.networkEnabled) {
      // Widget tests run offline — reflect locally without network.
      setState(() {
        _live = LiveTracking(
          status:
              _live?.status ??
              OrderStore.instance.statusOf(widget.orderId).name,
          estimatedArrivalMinutes: _live?.estimatedArrivalMinutes ?? 0,
          partnerName: _live?.partnerName,
          deliveryInstructions: text,
        );
      });
      if (mounted) showOxroSnack(context, 'Instructions saved');
      return;
    }
    final ok = await _repo.saveDeliveryInstructions(widget.orderId, text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _live = LiveTracking(
          status:
              _live?.status ??
              OrderStore.instance.statusOf(widget.orderId).name,
          estimatedArrivalMinutes: _live?.estimatedArrivalMinutes ?? 0,
          partnerName: _live?.partnerName,
          deliveryInstructions: text,
        );
      });
      showOxroSnack(context, 'Instructions saved');
    } else {
      showOxroSnack(context, 'Could not save instructions');
    }
  }

  // ─── optional guarantee ────────────────────────────────────

  Widget _arrivalGuaranteeCard(LiveTracking live) {
    return Container(
      key: const ValueKey('track_guarantee_card'),
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'On-Time Guarantee',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                if (live.guaranteeText != null)
                  Text(
                    live.guaranteeText!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── progress tracker ──────────────────────────────────────

  static const _stages = <(String, IconData)>[
    ('Order Confirmed', Icons.receipt_outlined),
    ('Restaurant Preparing', Icons.restaurant_outlined),
    ('Food Ready', Icons.check_circle_outline),
    ('Picked Up', Icons.delivery_dining_outlined),
    ('On The Way', Icons.directions_bike_outlined),
    ('Delivered', Icons.home_outlined),
  ];

  Widget _progressTracker(
    BuildContext context,
    OrderStatus status,
    List<TrackingStep> steps,
    int done,
    Color accent,
  ) {
    if (status == OrderStatus.cancelled) {
      return Container(
        key: const ValueKey('track_cancelled'),
        padding: EdgeInsets.all(context.rs(14)),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF5B5B0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: OxroColors.red, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This order was cancelled.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7B271F),
                ),
              ),
            ),
          ],
        ),
      );
    }
    const currentIdx = {
      OrderStatus.processing: 1,
      OrderStatus.shipped: 2,
      OrderStatus.outForDelivery: 4,
      OrderStatus.delivered: 5,
    };
    final current = currentIdx[status] ?? 1;

    return Container(
      key: const ValueKey('track_progress'),
      padding: EdgeInsets.fromLTRB(
        context.rs(12),
        context.rs(12),
        context.rs(12),
        context.rs(12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 18,
                color: OxroColors.royalBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(13.5),
                    fontWeight: FontWeight.w900,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _stages.length; i++)
            _progressStage(
              _stages[i],
              state: i < current
                  ? _StageState.done
                  : (i == current && status != OrderStatus.delivered)
                  ? _StageState.current
                  : (status == OrderStatus.delivered && i == _stages.length - 1)
                  ? _StageState.done
                  : _StageState.upcoming,
              terminalDelivered: status == OrderStatus.delivered,
            ),
        ],
      ),
    );
  }

  Widget _progressStage(
    (String, IconData) stage, {
    required _StageState state,
    required bool terminalDelivered,
  }) {
    final done = state == _StageState.done;
    final current = state == _StageState.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          current
              ? AnimatedBuilder(
                  animation: _ambient,
                  builder: (_, _) {
                    final pulse = (math.sin(_ambient.value * math.pi) + 1) / 2;
                    return Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OxroColors.green.withValues(
                            alpha: 0.6 + 0.4 * pulse,
                          ),
                          width: 2.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: OxroColors.green.withValues(
                            alpha: 0.15 + 0.25 * pulse,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          stage.$2,
                          size: 11,
                          color: OxroColors.green,
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: done
                        ? OxroColors.green.withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: done ? null : Border.all(color: OxroColors.border),
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: OxroColors.green,
                        )
                      : Icon(stage.$2, size: 14, color: OxroColors.muted),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage.$1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: done || current ? FontWeight.w800 : FontWeight.w600,
                color: done || current ? OxroColors.charcoal : OxroColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── address / summary / restaurant / support ──────────────

  Widget _trackRow(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(vertical: context.rs(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.rs(22), color: iconColor),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(13.5),
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(11.5),
                    color: OxroColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _orderSummaryRow(
    BuildContext context, {
    required int payable,
    required int itemCount,
    required String firstItem,
    required String statusPill,
    required String? savings,
    required String paymentStatus,
  }) {
    final countLabel = itemCount == 1 ? 'item' : 'items';
    return _trackRow(
      context,
      icon: Icons.shopping_bag_outlined,
      iconColor: OxroColors.charcoal,
      title: 'Order summary',
      subtitle:
          '${Money.inr(payable)} | $itemCount $countLabel • Payment: $paymentStatus',
      trailing: GestureDetector(
        key: const ValueKey('track_view_order'),
        onTap: _openOrderDetails,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            'View ›',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: OxroColors.authBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _restaurantRow(
    BuildContext context, {
    required String? kitchenId,
    required String? kitchenName,
    required Restaurant? restaurant,
  }) {
    final canOpen = kitchenId != null && RestaurantRepo.byId(kitchenId) != null;
    final restaurantSub = restaurant == null
        ? 'Freshly prepared for you'
        : '${restaurant.distanceLabel} away • View menu';
    final child = _trackRow(
      context,
      key: const ValueKey('track_restaurant'),
      icon: Icons.storefront_outlined,
      iconColor: OxroColors.primary,
      title: 'Restaurant',
      subtitle: restaurantSub,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: OxroColors.muted,
      ),
    );
    if (!canOpen) return child;
    return PressScale(onTap: () => _openRestaurant(kitchenId), child: child);
  }

  Widget _helpSupportRow(BuildContext context) {
    final rows = [
      (Icons.report_gmailerrorred_outlined, 'Missing items in order'),
      (Icons.schedule_outlined, 'Delivery is delayed'),
      (Icons.support_agent_outlined, 'Contact support'),
    ];
    return Column(
      key: const ValueKey('track_help_support'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Need help with this order?',
          style: TextStyle(
            fontSize: context.font(13.5),
            fontWeight: FontWeight.w900,
            color: OxroColors.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            leading: Icon(row.$1, color: OxroColors.royalBlue, size: 20),
            title: Text(
              row.$2,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OxroColors.charcoal,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: OxroColors.muted,
            ),
            onTap: () => _openHelp(),
          ),
      ],
    );
  }

  Widget _savingsTile(String savings) {
    return Container(
      key: const ValueKey('track_savings'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(10),
        vertical: context.rs(8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, size: 16, color: OxroColors.green),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              savings,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── promo section (preserved) ────────────────────────────

  Widget _promoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OXRO Spotlight',
          style: TextStyle(
            fontSize: context.font(18),
            fontWeight: FontWeight.w900,
            color: OxroColors.charcoal,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: context.rs(12)),
        _PromoGrid(onOpen: _openPromo),
        SizedBox(height: context.rs(14)),
        _premiumCard(context),
        SizedBox(height: context.rs(14)),
        _adCard(context),
        SizedBox(height: context.rs(18)),
        Center(
          child: Text(
            'It happens\nonly with OXRO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.font(30),
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
              color: OxroColors.muted.withValues(alpha: 0.28),
            ),
          ),
        ),
      ],
    );
  }

  void _openPromo(int action) {
    switch (action) {
      case 0:
        pushScreen(context, const PremiumScreen());
        break;
      case 1:
        pushScreen(context, SubCategoryScreen(category: homeCategories[0]));
        break;
      case 2:
        pushScreen(context, SubCategoryScreen(category: homeCategories[4]));
        break;
      default:
        pushScreen(context, const PremiumScreen());
    }
  }

  Widget _premiumCard(BuildContext context) {
    return ListenableBuilder(
      listenable: PremiumStore.instance,
      builder: (context, _) {
        final member = PremiumStore.instance.isMember;
        return Container(
          key: const ValueKey('track_premium_card'),
          padding: EdgeInsets.all(context.rs(16)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [OxroColors.premiumDeep, OxroColors.premiumWine],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: OxroColors.premiumChampagne.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 22,
                color: OxroColors.premiumChampagne,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member
                      ? 'OXRO PREMIUM member'
                      : 'Unlock FREE delivery with OXRO PREMIUM',
                  style: TextStyle(
                    fontSize: context.font(13),
                    fontWeight: FontWeight.w800,
                    color: OxroColors.premiumCream,
                  ),
                ),
              ),
              PressScale(
                key: const ValueKey('track_premium_cta'),
                onTap: () => pushScreen(context, const PremiumScreen()),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rs(12),
                    vertical: context.rs(8),
                  ),
                  decoration: BoxDecoration(
                    color: OxroColors.premiumCream,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    member ? 'Manage' : 'Join',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: OxroColors.premiumInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _adCard(BuildContext context) {
    return PressScale(
      key: const ValueKey('track_ad'),
      onTap: () =>
          pushScreen(context, SubCategoryScreen(category: homeCategories[0])),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OxroColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: context.rs(112),
              height: context.rs(96),
              child: Image.asset(
                FoodMedia.heroBbq,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [OxroColors.royalBlue, OxroColors.skyBlue],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(context.rs(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekend biryani festival',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.font(13.5),
                        fontWeight: FontWeight.w900,
                        color: OxroColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Fresh dum specials, hot to your door',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: OxroColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StageState { done, current, upcoming }

class _InstructionChip extends StatelessWidget {
  const _InstructionChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onTap == null ? OxroColors.pageBg : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: onTap == null ? OxroColors.border : const Color(0xFFBFD8F5),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: OxroColors.charcoal,
          ),
        ),
      ),
    );
  }
}

class _PromoGrid extends StatelessWidget {
  const _PromoGrid({required this.onOpen});

  final void Function(int action) onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PromoTile(
            key: const ValueKey('track_promo_0'),
            label: 'FREE DELIVERY',
            sub: 'with OXRO PREMIUM',
            accent: OxroColors.royalBlue,
            onTap: () => onOpen(0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PromoTile(
            key: const ValueKey('track_promo_1'),
            label: 'BIRYANI FEST',
            sub: 'Flat 30% off',
            accent: const Color(0xFFB3261E),
            onTap: () => onOpen(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PromoTile(
            key: const ValueKey('track_promo_2'),
            label: 'PIZZA CLUB',
            sub: 'Buy 1 get 1',
            accent: const Color(0xFF0A8CFF),
            onTap: () => onOpen(2),
          ),
        ),
      ],
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({
    super.key,
    required this.label,
    required this.sub,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String sub;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('track_divider'),
      height: 1,
      color: OxroColors.border,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
