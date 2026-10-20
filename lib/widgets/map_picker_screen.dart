import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'glass_toast.dart';
import 'ngam_maps_dialog.dart';

enum MapLayerType {
  voyager,         // CARTO Voyager (Standard Street Map - clean & light like Grab)
  darkMatter,      // CARTO Dark Matter (Dark Street Map)
  osm,             // OpenStreetMap Standard (Community Map)
  satelliteEsri,   // Esri World Imagery (High-res satellite photos)
}

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(3.140853, 101.693207); // Default KL
  LatLng? _userGpsLocation;
  bool _isLocating = false;
  MapLayerType _currentLayer = MapLayerType.voyager;
  late AnimationController _pulseController;

  // Search Autocomplete State
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Live Reverse Geocoding State (Grab-style)
  String _currentAddressTitle = 'Memuatkan alamat...';
  String _currentAddressSubtitle = 'Mencari lokasi terperinci...';
  bool _isReverseGeocoding = false;
  Timer? _reverseGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scheduleReverseGeocode(_currentCenter);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLocation == null) {
        _locateMe(isAuto: true);
      } else {
        _fetchInitialGps();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _reverseGeocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialGps() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _userGpsLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _currentCenter = camera.center;
      });
      _scheduleReverseGeocode(camera.center);
    }
  }

  void _scheduleReverseGeocode(LatLng target) {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isReverseGeocoding = true);
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${target.latitude}&lon=${target.longitude}&format=json&addressdetails=1',
        );
        final res = await http.get(uri, headers: {
          'User-Agent': 'NgamBusiness/1.0 (contact@ngam.dev)',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200 && mounted) {
          final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};
          final name = data['name']?.toString() ?? '';
          final road = addr['road']?.toString() ?? addr['suburb']?.toString() ?? '';
          final houseNumber = addr['house_number']?.toString() ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? '';
          final state = addr['state'] ?? '';

          String title = '';
          if (houseNumber.isNotEmpty && road.isNotEmpty) {
            title = '$houseNumber, $road';
          } else if (road.isNotEmpty) {
            title = 'Near $road';
          } else if (name.isNotEmpty) {
            title = name;
          } else {
            title = 'Lokasi Dipilih';
          }

          final subtitleParts = [
            if (addr['suburb'] != null && addr['suburb'] != road) addr['suburb'],
            if (city.toString().isNotEmpty) city,
            if (state.toString().isNotEmpty) state,
          ];
          final subtitle = subtitleParts.isNotEmpty
              ? subtitleParts.join(', ')
              : '${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)}';

          setState(() {
            _currentAddressTitle = title;
            _currentAddressSubtitle = subtitle;
            _isReverseGeocoding = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _currentAddressTitle = 'Lokasi Dipilih';
            _currentAddressSubtitle = 'GPS: ${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}';
            _isReverseGeocoding = false;
          });
        }
      }
    });
  }

  Future<void> _onSearchChanged(String query) async {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      if (_searchResults.isNotEmpty) {
        setState(() => _searchResults = []);
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);
      try {
        final results = <Map<String, dynamic>>[];

        // 1. Enjin Utama: Nominatim OpenStreetMap Malaysia
        try {
          final nomUri = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&addressdetails=1&limit=5&countrycodes=my',
          );
          final nomRes = await http.get(nomUri, headers: {
            'User-Agent': 'NgamBusiness/1.0 (contact@ngam.dev)',
          }).timeout(const Duration(seconds: 3));

          if (nomRes.statusCode == 200) {
            final list = json.decode(utf8.decode(nomRes.bodyBytes)) as List? ?? [];
            for (final item in list) {
              final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
              final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
              final name = item['name']?.toString() ?? '';
              final displayName = item['display_name']?.toString() ?? '';
              final addr = item['address'] as Map<String, dynamic>? ?? {};
              final subtitle = [
                addr['road'] ?? addr['suburb'],
                addr['city'] ?? addr['town'] ?? addr['county'],
                addr['state'],
              ].where((p) => p != null && p.toString().isNotEmpty).join(', ');

              if (lat != 0.0 && lon != 0.0) {
                results.add({
                  'title': name.isNotEmpty ? name : (subtitle.isNotEmpty ? subtitle : displayName),
                  'subtitle': subtitle.isNotEmpty ? subtitle : displayName,
                  'lat': lat,
                  'lng': lon,
                });
              }
            }
          }
        } catch (_) {}

        // 2. Sandaran (Fallback): Photon Komoot
        if (results.isEmpty) {
          try {
            final uri = Uri.parse(
              'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&limit=5&lat=${_currentCenter.latitude}&lon=${_currentCenter.longitude}',
            );
            final response = await http.get(uri).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              final data = json.decode(utf8.decode(response.bodyBytes));
              final features = data['features'] as List? ?? [];
              for (final f in features) {
                final props = f['properties'] as Map<String, dynamic>? ?? {};
                final geom = f['geometry'] as Map<String, dynamic>? ?? {};
                final coords = geom['coordinates'] as List? ?? [];
                if (coords.length >= 2) {
                  final lon = (coords[0] as num).toDouble();
                  final lat = (coords[1] as num).toDouble();
                  final name = props['name'] ?? props['street'] ?? '';
                  final parts = [
                    props['street'],
                    props['city'] ?? props['county'],
                    props['state'],
                  ].where((p) => p != null && p.toString().isNotEmpty && p != name).join(', ');

                  results.add({
                    'title': name.isNotEmpty ? name : (parts.isNotEmpty ? parts : 'Lokasi'),
                    'subtitle': parts,
                    'lat': lat,
                    'lng': lon,
                  });
                }
              }
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    final target = LatLng(lat, lng);
    setState(() {
      _currentCenter = target;
      _searchResults = [];
      _searchController.text = result['title'] as String;
    });
    _searchFocusNode.unfocus();
    _mapController.move(target, 17.0);
    _scheduleReverseGeocode(target);
    showGlassToast(context, 'Peta dialihkan ke: ${result['title']}');
  }

  String _getTileUrl() {
    switch (_currentLayer) {
      case MapLayerType.voyager:
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case MapLayerType.darkMatter:
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case MapLayerType.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapLayerType.satelliteEsri:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  Future<void> _locateMe({bool isAuto = false}) async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && !isAuto) {
          showGlassToast(context, 'GPS dimatikan. Sila buka tetapan lokasi.', isError: true);
          await Geolocator.openLocationSettings();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !isAuto) {
            showGlassToast(context, 'Keizinan GPS ditolak.', isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !isAuto) {
          showGlassToast(context, 'Keizinan GPS ditolak kekal.', isError: true);
          await Geolocator.openAppSettings();
        }
        return;
      }

      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final loc = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _userGpsLocation = loc;
          _currentCenter = loc;
        });
        _mapController.move(loc, 17.0);
        _scheduleReverseGeocode(loc);
      }

      Position currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      }

      final loc = LatLng(currentPos.latitude, currentPos.longitude);
      setState(() {
        _userGpsLocation = loc;
        _currentCenter = loc;
      });
      _mapController.move(loc, 17.0);
      _scheduleReverseGeocode(loc);

      if (mounted && !isAuto) {
        showGlassToast(context, 'GPS dijumpai: ${currentPos.latitude.toStringAsFixed(4)}, ${currentPos.longitude.toStringAsFixed(4)}');
      }
    } catch (e) {
      if (mounted && !isAuto) {
        showGlassToast(context, 'Sila seret peta ke pintu kedai anda.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Jenis Peta',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B14F).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Grab Style',
                      style: TextStyle(color: Color(0xFF00B14F), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tukar pandangan peta satelit bergambar atau jalan standard mengikut keselesaan anda.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Voyager Option (Default Grab Style)
              _buildLayerOption(
                type: MapLayerType.voyager,
                title: 'Peta Jalan Bersih (CARTO Voyager)',
                subtitle: 'Gaya Grab: Peta jalan cerah, bersih & mudah dibaca',
                icon: HugeIcons.strokeRoundedMapsLocation01,
                badge: 'Disyorkan',
              ),
              const SizedBox(height: 10),

              // OpenStreetMap Standard Option
              _buildLayerOption(
                type: MapLayerType.osm,
                title: 'Peta Komuniti (OpenStreetMap)',
                subtitle: 'Peta jalan standard komuniti dunia (100% percuma & sah)',
                icon: HugeIcons.strokeRoundedGlobe02,
              ),
              const SizedBox(height: 10),

              // Dark Matter Option
              _buildLayerOption(
                type: MapLayerType.darkMatter,
                title: 'Peta Jalan Gelap (CARTO Dark)',
                subtitle: 'Peta kontras tinggi tema gelap moden',
                icon: HugeIcons.strokeRoundedMoon02,
              ),
              const SizedBox(height: 10),

              // Pure Satellite (Esri)
              _buildLayerOption(
                type: MapLayerType.satelliteEsri,
                title: 'Satelit Foto Udara (Esri)',
                subtitle: 'Foto satelit fotografi resolusi tinggi',
                icon: HugeIcons.strokeRoundedEarth,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayerOption({
    required MapLayerType type,
    required String title,
    required String subtitle,
    required dynamic icon,
    String? badge,
  }) {
    final isSelected = _currentLayer == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() => _currentLayer = type);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00B14F).withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF00B14F) : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00B14F).withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: icon,
                  color: isSelected ? const Color(0xFF00B14F) : Colors.grey.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: const Color(0xFF1C1C1E),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B14F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00B14F),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── 1. Full Screen Map (Edge-to-Edge) ─────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 16.5,
                initialRotation: 0.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (tapPosition, point) {
                  setState(() {
                    _currentCenter = point;
                  });
                  _mapController.move(point, _mapController.camera.zoom);
                  _scheduleReverseGeocode(point);
                },
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                TileLayer(
                  key: ValueKey(_currentLayer),
                  urlTemplate: _getTileUrl(),
                  subdomains: const ['0', '1', '2', '3'],
                  userAgentPackageName: 'com.ngam.business',
                  tileBuilder: _currentLayer == MapLayerType.darkMatter
                      ? (context, tileWidget, tile) {
                          return ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              // Google Maps Official Dark Mode Color Matrix:
                               0.674, -1.406, -0.142, 0.0, 240.0,
                              -0.419, -0.314, -0.142, 0.0, 245.0,
                              -0.419, -1.406,  0.951, 0.0, 255.0,
                               0.0,    0.0,    0.0,   1.0,   0.0,
                            ]),
                            child: tileWidget,
                          );
                        }
                      : null,
                ),

                // Grab-style soft blue circular accuracy / selection halo around target
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentCenter,
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                      borderColor: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                      borderStrokeWidth: 1.5,
                      radius: 85,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),

                // User GPS blue dot if available (Grab Style)
                if (_userGpsLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userGpsLocation!,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E88E5),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // ── 2. Fixed Center Pin Overlay (Grab Style Teardrop & Pill)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42.0), // Align pin tip with exact map center
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grab-style "Drop-off point" / "Lokasi Kedai" Red Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935), // Grab red badge
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lokasi Kedai',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Red Pin with white dot in center
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.translate(
                           offset: Offset(0, -(_pulseController.value * 4)),
                           child: child,
                         );
                      },
                      child: SizedBox(
                        width: 42,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 46,
                              color: Color(0xFFE53935),
                            ),
                            Positioned(
                              top: 13,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ground shadow underneath pin tip
                    Container(
                      width: 14,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Top Floating Navigation Bar (Grab Style) ──
            Positioned(
              top: topPadding + 12,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Back Button (Circular White Button)
                      _buildCircularWhiteBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        tooltip: 'Kembali',
                      ),
                      const SizedBox(width: 10),

                      // Search Bar Capsule (Tap to expand or type)
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF00B14F),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: _onSearchChanged,
                                  style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Cari alamat, jalan, atau kawasan...',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_isSearching)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B14F)),
                                  ),
                                )
                              else if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Globe / Layers Switcher Button (Circular White Button)
                      _buildCircularWhiteBtn(
                        icon: Icons.language_rounded,
                        onTap: _showLayerSelector,
                        tooltip: 'Tukar Peta',
                      ),
                    ],
                  ),

                  // Search Results Dropdown List
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B14F).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Color(0xFF00B14F), size: 16),
                            ),
                            title: Text(
                              item['title'] as String,
                              style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: (item['subtitle'] as String).isNotEmpty
                                ? Text(
                                    item['subtitle'] as String,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _selectSearchResult(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // ── 4. Map Action Controls (Floating Above Bottom Sheet) ──
            Positioned(
              bottom: 175,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // GrabMaps Attribution Badge (Bottom Left)
                  const NgamMapsAttributionBadge(isDark: false),

                  // GPS / Crosshair Button (Bottom Right)
                  _buildCircularWhiteBtn(
                    size: 46,
                    icon: Icons.my_location_rounded,
                    iconColor: const Color(0xFF1C1C1E),
                    isLoading: _isLocating,
                    onTap: () => _locateMe(isAuto: false),
                    tooltip: 'Lokasi Saya',
                  ),
                ],
              ),
            ),

            // ── 5. Grab-Style Bottom Destination Sheet ──────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle Pill
                      Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D1D6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Location Detail Row (Grab Screenshot 2 Style)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F8EE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF00B14F),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _currentAddressTitle,
                                        style: const TextStyle(
                                          color: Color(0xFF1C1C1E),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_isReverseGeocoding) ...[
                                      const SizedBox(width: 6),
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF00B14F)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '0km • $_currentAddressSubtitle',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                            onPressed: _showLayerSelector,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Big Grab Green Pill CTA Button: "Choose This Destination"
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, _currentCenter);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B14F), // Vibrant Grab Green
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: const Text(
                            'Choose This Destination',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularWhiteBtn({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color iconColor = const Color(0xFF1C1C1E),
    double size = 42,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B14F)),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
