import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'glass_toast.dart';

enum MapLayerType {
  voyager,         // CARTO Voyager (Standard Street Map)
  darkMatter,      // CARTO Dark Matter (Dark Street Map)
  satelliteHybrid, // Google Hybrid Satellite (free, with road & street labels)
  satelliteEsri,   // Esri World Imagery (free high-res satellite photos)
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
  bool _isLocating = false;
  MapLayerType _currentLayer = MapLayerType.voyager;
  late AnimationController _pulseController;

  // Search Autocomplete State
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.initialLocation == null) {
      // Delay slightly to allow map widget to render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locateMe(isAuto: true);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
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
        final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&limit=5&lat=${_currentCenter.latitude}&lon=${_currentCenter.longitude}',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 && mounted) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final features = data['features'] as List? ?? [];
          final results = <Map<String, dynamic>>[];
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
    showGlassToast(context, 'Peta dialihkan ke: ${result['title']}');
  }

  static const String _cartoApiKey = 'cb1_470b_1_5dec1f354e103fb7efca8d68';

  String _getTileUrl() {
    switch (_currentLayer) {
      case MapLayerType.voyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$_cartoApiKey';
      case MapLayerType.darkMatter:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png?key=$_cartoApiKey';
      case MapLayerType.satelliteHybrid:
        // Google Hybrid Satellite (satellite + road labels, free, no API key required)
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case MapLayerType.satelliteEsri:
        // Esri ArcGIS World Imagery (pure satellite photography, free, no API key required)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  Future<void> _locateMe({bool isAuto = false}) async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && !isAuto) {
          showGlassToast(context, 'GPS is turned off. Opening location settings...', isError: true);
          await Geolocator.openLocationSettings();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !isAuto) {
            showGlassToast(context, 'Location permission denied. Please allow to pin GPS.', isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !isAuto) {
          showGlassToast(context, 'Location permission permanently denied. Open app settings to enable.', isError: true);
          await Geolocator.openAppSettings();
        }
        return;
      }

      // Quick fallback: check last known position first
      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final loc = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() => _currentCenter = loc);
        _mapController.move(loc, 16.5);
      }

      // Fetch fresh high-accuracy position with fallback
      Position currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // Fallback to medium accuracy if high accuracy times out (e.g. indoors)
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      }

      final loc = LatLng(currentPos.latitude, currentPos.longitude);
      setState(() => _currentCenter = loc);
      _mapController.move(loc, 17.0);

      if (mounted) {
        showGlassToast(context, 'GPS located: ${currentPos.latitude.toStringAsFixed(4)}, ${currentPos.longitude.toStringAsFixed(4)}');
      }
    } catch (e) {
      debugPrint("Locate error: $e");
      if (mounted && !isAuto) {
        showGlassToast(context, 'GPS signal weak indoors. Drag map to pin shop entrance.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom < 19) {
      _mapController.move(_currentCenter, currentZoom + 1.0);
    }
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom > 4) {
      _mapController.move(_currentCenter, currentZoom - 1.0);
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
            color: const Color(0xFF161622),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Pilih Jenis Peta (Map Layer)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '100% Percuma',
                      style: TextStyle(color: Color(0xFF44CF6C), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tukar pandangan peta satelit bergambar atau jalan standard untuk mencari lokasi kedai dengan tepat.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Voyager Option
              _buildLayerOption(
                type: MapLayerType.voyager,
                title: 'Peta Jalan Terang (CARTO Voyager)',
                subtitle: 'Peta jalan standard CARTO terang dengan nama jalan & bangunan',
                icon: HugeIcons.strokeRoundedMapsLocation01,
              ),
              const SizedBox(height: 12),

              // Dark Matter Option
              _buildLayerOption(
                type: MapLayerType.darkMatter,
                title: 'Peta Jalan Gelap (CARTO Dark Matter)',
                subtitle: 'Peta jalan tema gelap CARTO dengan kontras tinggi',
                icon: HugeIcons.strokeRoundedMoon02,
              ),
              const SizedBox(height: 12),

              // Satellite Hybrid Option
              _buildLayerOption(
                type: MapLayerType.satelliteHybrid,
                title: 'Satelit Bergambar + Jalan (Hybrid)',
                subtitle: 'Foto udara satelit dengan nama jalan & penanda kedai',
                icon: HugeIcons.strokeRoundedEarth,
                badge: 'Disyorkan',
              ),
              const SizedBox(height: 12),

              // Pure Satellite (Esri)
              _buildLayerOption(
                type: MapLayerType.satelliteEsri,
                title: 'Satelit Asli (Esri World Imagery)',
                subtitle: 'Foto satelit fotografi resolusi tinggi tanpa teks jalan',
                icon: HugeIcons.strokeRoundedGlobe02,
              ),
              const SizedBox(height: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF42A5F5).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: icon,
                  color: isSelected ? const Color(0xFF42A5F5) : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
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
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: Color(0xFF42A5F5),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161622),
        elevation: 0,
        title: const Text('Pin Business Location'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tukar Jenis Peta',
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMapsLocation01, color: Colors.white, size: 22),
            onPressed: _showLayerSelector,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.0,
              initialRotation: 0.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) {
                setState(() {
                  _currentCenter = point;
                });
                _mapController.move(point, _mapController.camera.zoom);
              },
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentCenter = camera.center;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_currentLayer),
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.ngam.business',
              ),
            ],
          ),

          // Fixed Center Pin Overlay with pulse animation
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44.0), // Center pin tip on crosshair
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -(_pulseController.value * 6)),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        color: Color(0xFF42A5F5),
                        size: 48,
                      ),
                    ),
                  ),
                  // Drop shadow underneath pin
                  Container(
                    width: 12,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Control Bar: Search Autocomplete & Layer Switcher
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Address Search Field
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF161622).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: Color(0xFF42A5F5),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _onSearchChanged,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Cari alamat, jalan, atau kawasan...',
                                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5)),
                                ),
                              )
                            else if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Layer Switcher Floating Pill
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: _showLayerSelector,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161622).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: _currentLayer == MapLayerType.voyager
                                    ? HugeIcons.strokeRoundedMapsLocation01
                                    : _currentLayer == MapLayerType.darkMatter
                                        ? HugeIcons.strokeRoundedMoon02
                                        : HugeIcons.strokeRoundedEarth,
                                color: const Color(0xFF42A5F5),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentLayer == MapLayerType.voyager
                                    ? 'Voyager'
                                    : _currentLayer == MapLayerType.darkMatter
                                        ? 'Dark'
                                        : _currentLayer == MapLayerType.satelliteHybrid
                                            ? 'Hybrid'
                                            : 'Esri',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Search Results Dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161626).withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: Color(0xFF42A5F5), size: 18),
                          title: Text(item['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: (item['subtitle'] as String).isNotEmpty ? Text(item['subtitle'] as String, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Right Side Map Controls (Circular Glassmorphic + - and GPS)
          Positioned(
            bottom: 230,
            right: 16,
            child: Column(
              children: [
                // Zoom In Button (Circular Glassmorphic)
                _buildGlassCircleBtn(
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    color: Colors.white,
                    size: 20,
                  ),
                  onTap: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 10),

                // Zoom Out Button (Circular Glassmorphic)
                _buildGlassCircleBtn(
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRemove01,
                    color: Colors.white,
                    size: 20,
                  ),
                  onTap: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 14),

                // GPS My Location Circular Glassmorphic Button
                _buildGlassCircleBtn(
                  size: 48,
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF42A5F5),
                          ),
                        )
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedNavigation03,
                          color: Color(0xFF42A5F5),
                          size: 22,
                        ),
                  onTap: () => _locateMe(isAuto: false),
                  tooltip: 'Locate GPS',
                ),
              ],
            ),
          ),

          // Bottom Bar & Confirm Panel
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161622).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          color: Color(0xFF42A5F5),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Seret peta untuk tetapkan pin tepat di hadapan pintu kedai anda.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // GPS Coordinates Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: Color(0xFF42A5F5), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'GPS: ${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Confirm Location Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, _currentCenter);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sahkan Lokasi Kedai',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleBtn({
    required Widget child,
    required VoidCallback onTap,
    required String tooltip,
    double size = 46,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.transparent,
              highlightColor: Colors.white.withValues(alpha: 0.08),
              onTap: onTap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF161626).withValues(alpha: 0.75),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
