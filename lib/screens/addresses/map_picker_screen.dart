import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

/// Full-screen map to pin a shipping address precisely: the customer drags
/// the map under a fixed centre pin, then confirms. Pops the chosen
/// [LatLng]. Uses OpenStreetMap tiles (no API key needed); the saved
/// coordinates open the same spot in Google Maps.
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Monas, Jakarta — only until the device location (or the saved pin) loads.
  static const _fallback = LatLng(-6.1754, 106.8272);

  final MapController _map = MapController();
  late LatLng _center = widget.initial ?? _fallback;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) _goToMyLocation();
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      _map.move(here, 17);
      setState(() => _center = here);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi kamu belum terbaca. Geser peta ke alamat pengiriman.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Titik Lokasi')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial != null ? 17 : 13,
              minZoom: 4,
              maxZoom: 19,
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.petope.app',
              ),
              const SimpleAttributionWidget(source: Text('© OpenStreetMap')),
            ],
          ),
          // Fixed pin: its tip marks the map centre.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on_rounded, size: 48, color: Color(0xFFE0453A)),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
              ),
              child: const Text(
                'Geser peta sampai pin merah tepat di lokasi pengiriman (depan rumah / gedung).',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 104,
            child: FloatingActionButton.small(
              heroTag: 'my-location',
              backgroundColor: AppColors.surface,
              onPressed: _locating ? null : _goToMyLocation,
              child: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, color: AppColors.purple),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: GradientButton(
                label: 'Gunakan Titik Ini',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(_center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
