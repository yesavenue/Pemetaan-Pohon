import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../utils/cirebon_boundary.dart';
import '../../utils/device_location.dart';

/// Hanya mengembalikan koordinat ke form; tidak menulis database.
class TreeLocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const TreeLocationPickerScreen({super.key, this.initialLocation});

  @override
  State<TreeLocationPickerScreen> createState() =>
      _TreeLocationPickerScreenState();
}

class _TreeLocationPickerScreenState extends State<TreeLocationPickerScreen> {
  final _mapController = MapController();
  LatLng? _selected;
  bool _ready = false;
  bool _locating = false;
  bool _tileError = false;
  int _tileVersion = 0;

  bool get _valid =>
      _selected != null &&
      isInsideCirebon(_selected!.latitude, _selected!.longitude);

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoom(double delta) {
    if (!_ready) {
      return;
    }
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(3.0, 19.0).toDouble(),
    );
  }

  Future<void> _locate() async {
    if (_locating || !_ready) {
      return;
    }
    setState(() => _locating = true);
    try {
      final point = await readDeviceLocation();
      if (!mounted) {
        return;
      }
      setState(() => _selected = point);
      _mapController.move(point, 17);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _markTileError() {
    if (_tileError) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) {
        setState(() => _tileError = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Lokasi Pohon')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 400) {
            return SingleChildScrollView(
              child: SizedBox(height: 600, child: _content()),
            );
          }
          return _content();
        },
      ),
    );
  }

  Widget _content() {
    final point = _selected;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Ketuk peta untuk menempatkan pin pada lokasi pohon.'),
        ),
        if (_tileError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sebagian peta gagal dimuat.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tileError = false;
                    _tileVersion++;
                  }),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      widget.initialLocation ?? const LatLng(-6.7183, 108.5522),
                  initialZoom: widget.initialLocation == null ? 14 : 17,
                  minZoom: 3,
                  onMapReady: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _ready = true);
                      }
                    });
                  },
                  maxZoom: 19,
                  onTap: (_, point) {
                    if (!_locating) {
                      setState(() => _selected = point);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    key: ValueKey(_tileVersion),
                    errorTileCallback: (_, error, stack) => _markTileError(),
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pemetaanpohon.app',
                  ),
                  if (point != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.location_on,
                            size: 42,
                            color: _valid ? AppColors.leaf : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      const TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 12,
                top: 12,
                bottom: 24,
                child: SingleChildScrollView(
                  child: Card(
                    child: Column(
                      children: [
                        IconButton(
                          tooltip: 'Perbesar',
                          onPressed: _ready ? () => _zoom(1) : null,
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Perkecil',
                          onPressed: _ready ? () => _zoom(-1) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Lokasi saya',
                          onPressed: _ready && !_locating ? _locate : null,
                          icon: _locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.location_on,
                    color: _valid ? AppColors.leaf : Colors.blueGrey,
                  ),
                  title: const Text('Lokasi Dipilih'),
                  subtitle: Text(
                    point == null
                        ? 'Belum ada titik dipilih.'
                        : '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                  ),
                ),
                if (point != null && !_valid)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Pilih titik di dalam wilayah Kota Cirebon.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                FilledButton(
                  onPressed: _valid && !_locating
                      ? () => Navigator.pop(context, _selected)
                      : null,
                  child: const Text('Konfirmasi Lokasi'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}