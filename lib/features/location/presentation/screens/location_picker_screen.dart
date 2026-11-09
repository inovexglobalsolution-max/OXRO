import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/location/data/photon_client.dart';

/// What the customer picked on the map.
class LocationPick {
  const LocationPick({
    required this.latitude,
    required this.longitude,
    this.line,
    this.city,
    this.state,
    this.pin,
    this.landmark,
    this.displayName,
  });

  final double latitude;
  final double longitude;
  final String? line;
  final String? city;
  final String? state;
  final String? pin;
  final String? landmark;
  final String? displayName;

  String get pinLabel => '${_f(latitude)}, ${_f(longitude)}';

  static String _f(double v) => v.toStringAsFixed(5);
}

/// India-only delivery footprint — keeps picks inside the service area.
const _indiaSouthWest = LatLng(6.5, 67.5);
const _indiaNorthEast = LatLng(37.5, 97.5);

/// Interactive delivery-location picker: GPS (primary), OpenStreetMap via
/// flutter_map, Photon search + reverse geocoding. Never fakes a location —
/// the confirm button is disabled until the customer picks a real point.
class LocationPickerScreen extends StatefulWidget {
  /// Test hook: when false, OSM tiles are replaced with a deterministic
  /// local placeholder so widget tests never hit the network.
  static bool liveTiles = true;

  LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    bool? useLiveTiles,
  }) : useLiveTiles = useLiveTiles ?? liveTiles;

  final double? initialLatitude;
  final double? initialLongitude;

  /// Tests pass false — widget tests must never fetch OSM tiles over network.
  final bool useLiveTiles;

  /// Test seam: replaces the GPS probe (permission dialogs can't run in
  /// widget tests). Returns null = unavailable/denied.
  @visibleForTesting
  static Future<LatLng?> Function()? gpsProbe;

  @visibleForTesting
  static Future<void> resetForTests() async {
    gpsProbe = null;
  }

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _searchFocus = FocusNode();

  Timer? _searchDebounce;
  Timer? _reverseDebounce;

  double? _lat;
  double? _lng;
  bool _locating = false;
  String? _locationError;
  String? _pinLabel;
  bool _mapReady = false;

  List<PhotonSuggestion> _suggestions = const [];
  bool _searching = false;
  PhotonSuggestion? _reverse;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null) {
      _lat = lat;
      _lng = lng;
      _pinLabel = LocationPick(latitude: lat, longitude: lng).pinLabel;
      _reverseGeocodeLater();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detectGps());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _searchController.dispose();
    _landmarkController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── Location ────────────────────────────────────────────────

  Future<void> _detectGps() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    LatLng? point;
    try {
      final probe = LocationPickerScreen.gpsProbe;
      if (probe != null) {
        point = await probe().timeout(const Duration(seconds: 6));
      } else {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _applyError('Location services are off. Turn on GPS and tap retry.');
          return;
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          _applyError(
            'Location permission is permanently denied. '
            'Allow it in Settings to deliver to your address.',
          );
          return;
        }
        if (permission == LocationPermission.denied) {
          _applyError('Location permission was denied.');
          return;
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 10));
        point = LatLng(position.latitude, position.longitude);
      }
      if (point == null) {
        _applyError("Couldn't get your GPS location. Tap retry.");
        return;
      }
      if (!_inIndia(point)) {
        _applyError('Delivery available in India only.');
        return;
      }
      _applyLocation(point.latitude, point.longitude, moveMap: true);
      _reverseGeocodeLater();
    } on TimeoutException {
      _applyError('Location detection timed out. Tap retry.');
    } on LocationServiceDisabledException {
      _applyError('Location services are off. Turn on GPS and tap retry.');
    } on PermissionDeniedException {
      _applyError('Location permission denied.');
    } on Exception {
      _applyError("Couldn't get your GPS location. Tap retry.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _applyError(String message) {
    if (!mounted) return;
    setState(() => _locationError = message);
  }

  bool _inIndia(LatLng p) =>
      p.latitude >= _indiaSouthWest.latitude &&
      p.latitude <= _indiaNorthEast.latitude &&
      p.longitude >= _indiaSouthWest.longitude &&
      p.longitude <= _indiaNorthEast.longitude;

  void _applyLocation(double lat, double lng, {bool moveMap = true}) {
    if (!mounted) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      _pinLabel = LocationPick(latitude: lat, longitude: lng).pinLabel;
      _locationError = null;
    });
    if (moveMap && _mapReady && widget.useLiveTiles) {
      _mapController.move(LatLng(lat, lng), 16);
    }
  }

  void _reverseGeocodeLater() {
    _reverseDebounce?.cancel();
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return;
    _reverseDebounce = Timer(const Duration(milliseconds: 260), () async {
      final place = await PhotonClient.shared.reverse(lat, lng);
      if (!mounted) return;
      setState(() => _reverse = place);
    });
  }

  // ─── Search ──────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 320), () async {
      setState(() => _searching = true);
      final results = await PhotonClient.shared.search(trimmed, limit: 6);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _suggestions = results;
      });
    });
  }

  void _selectSuggestion(PhotonSuggestion suggestion) {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _searchController.text = suggestion.displayName;
      _reverse = suggestion;
    });
    _applyLocation(suggestion.latitude, suggestion.longitude);
  }

  void _confirmPick() {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return;
    final reverse = _reverse;
    final pick = LocationPick(
      latitude: lat,
      longitude: lng,
      line: reverse?.line ?? reverse?.displayName,
      city: reverse?.city,
      state: reverse?.state,
      pin: reverse?.pin,
      landmark: _landmarkController.text.trim().isEmpty
          ? null
          : _landmarkController.text.trim(),
      displayName: reverse?.displayName,
    );
    Navigator.of(context).pop(pick);
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lat = _lat;
    final lng = _lng;
    final hasPin = lat != null && lng != null;
    return Scaffold(
      backgroundColor: OxroColors.cream,
      appBar: AppBar(
        title: const Text('Select delivery location'),
        actions: [
          IconButton(
            key: const ValueKey('location_recenter'),
            tooltip: 'Recenter map',
            onPressed: _recenter,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _bottomPanelHeight(context),
            child: _MapSurface(
              key: const ValueKey('location_map'),
              mapController: _mapController,
              lat: lat ?? 20.5937,
              lng: lng ?? 78.9629,
              zoom: lat != null ? 16 : 5,
              useLiveTiles: widget.useLiveTiles,
              onReady: () {
                _mapReady = true;
                final lat0 = _lat, lng0 = _lng;
                if (lat0 != null && lng0 != null) {
                  _mapController.move(LatLng(lat0, lng0), 16);
                }
              },
              onMoveEnd: (center) {
                _applyLocation(
                  center.latitude,
                  center.longitude,
                  moveMap: false,
                );
                _reverseGeocodeLater();
              },
              onTap: (point) {
                _applyLocation(point.latitude, point.longitude, moveMap: true);
                _reverseGeocodeLater();
              },
            ),
          ),
          // Zoom controls — kept above the map, below the pin.
          Positioned(
            right: 12,
            bottom: _bottomPanelHeight(context) + 96,
            child: Column(
              children: [
                _circleButton(
                  const ValueKey('location_zoom_in'),
                  Icons.add_rounded,
                  () => _zoomBy(1),
                ),
                const SizedBox(height: 8),
                _circleButton(
                  const ValueKey('location_zoom_out'),
                  Icons.remove_rounded,
                  () => _zoomBy(-1),
                ),
              ],
            ),
          ),
          // Fixed crosshair — the pin is the map's center.
          Positioned(
            top: _crosshairTop(context),
            left: 0,
            right: 0,
            child: IgnorePointer(
              key: const ValueKey('location_crosshair'),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: context.rs(46),
                      color: OxroColors.primary,
                    ),
                    Transform.translate(
                      offset: Offset(0, -context.rs(6)),
                      child: Container(
                        width: context.rs(8),
                        height: context.rs(8),
                        decoration: const BoxDecoration(
                          color: OxroColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Search bar + suggestions — floating at the top.
          Positioned(
            top: MediaQuery.of(context).padding.top + context.rs(10),
            left: context.padX,
            right: context.padX,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  loading: _searching,
                  onClear: () => setState(() {
                    _searchController.clear();
                    _suggestions = const [];
                  }),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SuggestionPanel(
                    suggestions: _suggestions,
                    onSelect: _selectSuggestion,
                  ),
                ],
                if (_locating) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0,
                    minHeight: 3,
                    key: const ValueKey('location_loading'),
                    backgroundColor: OxroColors.border,
                    valueColor: AlwaysStoppedAnimation(OxroColors.primary),
                  ),
                ],
                if (_locationError != null) ...[
                  const SizedBox(height: 8),
                  _LocationErrorCard(
                    message: _locationError!,
                    onRetry: _detectGps,
                  ),
                ],
              ],
            ),
          ),
          // Bottom panel — selected address + confirm.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              lat: lat,
              lng: lng,
              pinLabel: _pinLabel,
              placeLine: _reverse?.displayName,
              pinText: _pinLabel,
              city: _reverse?.city,
              pin: _reverse?.pin,
              landmarkController: _landmarkController,
              locating: _locating,
              onUseCurrent: _detectGps,
              onConfirm: hasPin ? _confirmPick : null,
            ),
          ),
        ],
      ),
    );
  }

  double _bottomPanelHeight(BuildContext context) {
    return context.rs(210);
  }

  double _crosshairTop(BuildContext context) {
    // Optical center of the visible map area, minus half the icon height.
    final visible =
        MediaQuery.of(context).size.height -
        (_bottomPanelHeight(context) +
            kToolbarHeight +
            MediaQuery.of(context).padding.top);
    return (MediaQuery.of(context).padding.top + kToolbarHeight + visible / 2) -
        context.rs(23);
  }

  Future<void> _recenter() async {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) {
      await _detectGps();
      return;
    }
    if (_mapReady && widget.useLiveTiles) {
      _mapController.move(LatLng(lat, lng), 16);
    }
  }

  Future<void> _zoomBy(double delta) async {
    if (!_mapReady || !widget.useLiveTiles) return;
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(1.0, 19.0).toDouble();
    _mapController.move(camera.center, zoom);
  }

  Widget _circleButton(Key key, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: OxroColors.border)),
      elevation: 2,
      child: InkWell(
        key: key,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: OxroColors.charcoal, size: 20),
        ),
      ),
    );
  }
}

class _MapSurface extends StatelessWidget {
  const _MapSurface({
    super.key,
    required this.mapController,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.useLiveTiles,
    required this.onReady,
    required this.onMoveEnd,
    required this.onTap,
  });

  final MapController mapController;
  final double lat;
  final double lng;
  final double zoom;
  final bool useLiveTiles;
  final VoidCallback onReady;
  final ValueChanged<LatLng> onMoveEnd;
  final ValueChanged<LatLng> onTap;

  @override
  Widget build(BuildContext context) {
    if (!useLiveTiles) {
      // Deterministic stand-in for widget tests: same semantics, no network.
      return _TestMap(onReady: onReady);
    }
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: zoom,
        minZoom: 4,
        maxZoom: 19,
        onMapReady: onReady,
        onMapEvent: (event) {
          if (event is MapEventMoveEnd) {
            onMoveEnd(event.camera.center);
          }
        },
        onTap: (_, point) => onTap(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.oxro.app',
        ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

/// Static placeholder so picker widget tests never hit the network.
class _TestMap extends StatefulWidget {
  const _TestMap({required this.onReady});

  final VoidCallback onReady;

  @override
  State<_TestMap> createState() => _TestMapState();
}

class _TestMapState extends State<_TestMap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EDF2),
      child: const Center(
        child: Icon(Icons.map_outlined, size: 88, color: Color(0xFFB8C4CE)),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.loading,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool loading;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: OxroColors.border),
      ),
      child: TextField(
        key: const ValueKey('location_search'),
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: OxroColors.charcoal),
        decoration: InputDecoration(
          hintText: 'Search for area, building, street…',
          hintStyle: const TextStyle(color: OxroColors.muted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: OxroColors.charcoal,
          ),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('location_clear_search'),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OxroColors.muted,
                  ),
                  onPressed: onClear,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.suggestions, required this.onSelect});

  final List<PhotonSuggestion> suggestions;
  final ValueChanged<PhotonSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.separated(
          key: const ValueKey('location_results'),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return InkWell(
              key: ValueKey('location_result_$index'),
              onTap: () => onSelect(suggestion),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: OxroColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        suggestion.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: OxroColors.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LocationErrorCard extends StatelessWidget {
  const _LocationErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDECEA),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Color(0xFFC33F33)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                key: const ValueKey('location_error'),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF7B271F),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              key: const ValueKey('location_retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.lat,
    required this.lng,
    required this.pinLabel,
    required this.placeLine,
    required this.pinText,
    required this.city,
    required this.pin,
    required this.landmarkController,
    required this.locating,
    required this.onUseCurrent,
    required this.onConfirm,
  });

  final double? lat;
  final double? lng;
  final String? pinLabel;
  final String? placeLine;
  final String? pinText;
  final String? city;
  final String? pin;
  final TextEditingController landmarkController;
  final bool locating;
  final VoidCallback onUseCurrent;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final hasPin = lat != null && lng != null;
    final line = placeLine?.trim();
    final hasLine = line != null && line.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          context.padX,
          context.rs(12),
          context.padX,
          context.rs(12),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: OxroColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pin_drop_rounded,
                  color: OxroColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasLine
                            ? line
                            : 'Move the map to your delivery address',
                        key: const ValueKey('location_address_line'),
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
                        hasPin ? (pinText ?? '') : 'Detecting your location…',
                        key: const ValueKey('location_coords'),
                        style: TextStyle(
                          fontSize: context.font(10.5),
                          color: OxroColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (city != null && city!.trim().isNotEmpty)
                        Text(
                          city!,
                          style: TextStyle(
                            fontSize: context.font(10.5),
                            color: OxroColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('location_landmark'),
              controller: landmarkController,
              textInputAction: TextInputAction.done,
              maxLength: 80,
              buildCounter:
                  (
                    BuildContext context, {
                    int? currentLength,
                    int? maxLength,
                    bool? isFocused,
                  }) => null,
              decoration: InputDecoration(
                hintText: 'Landmark (optional) — e.g. Near Apollo Hospital',
                hintStyle: const TextStyle(
                  color: OxroColors.muted,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.place_outlined,
                  color: OxroColors.muted,
                  size: 18,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: OxroColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: OxroColors.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('location_use_current'),
                  onPressed: locating ? null : onUseCurrent,
                  icon: locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(locating ? 'Locating…' : 'Use Current Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OxroColors.charcoal,
                    side: const BorderSide(color: OxroColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('location_confirm'),
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: OxroColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Confirm location',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
