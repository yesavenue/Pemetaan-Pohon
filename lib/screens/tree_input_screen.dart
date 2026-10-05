import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../utils/cirebon_boundary.dart';
import '../utils/geo_utils.dart';
import '../utils/tree_condition_style.dart';
import '../utils/tree_options.dart';

class TreeInputScreen extends StatefulWidget {
  final AppUser surveyorUser;
  const TreeInputScreen({super.key, required this.surveyorUser});

  @override
  State<TreeInputScreen> createState() => _TreeInputScreenState();
}

class _TreeInputScreenState extends State<TreeInputScreen> {
  final _treeService = TreeService();
  final _customSpeciesController = TextEditingController();
  final _kecamatanCustomController = TextEditingController();
  final _kelurahanController = TextEditingController();
  final _namaJalanController = TextEditingController();
  final _keteranganKondisiController = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedSpecies;
  String? _selectedKecamatan;
  TreeCondition _condition = TreeCondition.sehat;

  Uint8List? _photoBytes;
  String? _photoBase64;

  Position? _position;
  bool _isFetchingLocation = false;
  String? _locationError;

  bool _isSaving = false;

  String get _effectiveSpecies {
    if (_selectedSpecies == 'Lainnya') {
      return _customSpeciesController.text.trim();
    }
    return _selectedSpecies ?? '';
  }

  String get _effectiveKecamatan {
    if (_selectedKecamatan == 'Lainnya') {
      return _kecamatanCustomController.text.trim();
    }
    return _selectedKecamatan ?? '';
  }

  bool get _isLocationValid =>
      _position != null && isInsideCirebon(_position!.latitude, _position!.longitude);

  bool get _requiresKeterangan =>
      _condition == TreeCondition.sakit || _condition == TreeCondition.rawanTumbang;

  bool get _canSubmit =>
      !_isSaving &&
      _effectiveSpecies.isNotEmpty &&
      _effectiveKecamatan.isNotEmpty &&
      _namaJalanController.text.trim().isNotEmpty &&
      _photoBase64 != null &&
      _position != null &&
      _isLocationValid &&
      (!_requiresKeterangan || _keteranganKondisiController.text.trim().isNotEmpty);

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
      maxWidth: 900,
    );
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    final base64Str = base64Encode(bytes);

    if (base64Str.length > 700000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto terlalu besar, coba ambil ulang.')),
      );
      return;
    }

    setState(() {
      _photoBytes = bytes;
      _photoBase64 = base64Str;
    });
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi (GPS) tidak aktif. Aktifkan terlebih dahulu.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _position = position;
        _isFetchingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = e.toString().replaceFirst('Exception: ', '');
        _isFetchingLocation = false;
      });
    }
  }

  void _showConditionGuide() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Panduan Ciri-Ciri Kondisi Pohon'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guideSection(
                    title: 'Sakit',
                    color: treeConditionColor(TreeCondition.sakit),
                    points: const [
                      'Daun tampak kusam, pucat, atau layu ringan padahal tanah cukup basah',
                      'Muncul bercak kuning/cokelat/hitam pada daun yang makin melebar',
                      'Daun rontok di luar musim atau siklus normalnya',
                      'Tunas baru kerdil, atau ujung dahan mulai mengering',
                      'Kulit batang memar, melunak, retak tipis, atau keluar getah tak wajar',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _guideSection(
                    title: 'Rawan Tumbang',
                    color: treeConditionColor(TreeCondition.rawanTumbang),
                    points: const [
                      'Batang miring tajam (lebih dari ~30°) atau kemiringan berubah mendadak',
                      'Tanah di sekitar akar terangkat, retak, atau bergelombang',
                      'Batang keropos/berlubang di bagian dalam',
                      'Ada retakan vertikal dalam yang membelah batang utama',
                      'Tumbuh jamur di pangkal batang (tanda akar/pangkal mulai busuk)',
                      'Tajuk berat sebelah, daun/dahan hanya lebat di satu sisi',
                      'Banyak cabang besar yang mati, kering, atau menggantung patah',
                      'Akar terpotong atau tertutup semen akibat galian/proyek',
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          ],
        );
      },
    );
  }

  Widget _guideSection({required String title, required Color color, required List<String> points}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ...points.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $p', style: const TextStyle(fontSize: 13)),
            )),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _isSaving = true);

    final nearbyTrees = await _treeService.findNearbyTrees(
      _position!.latitude,
      _position!.longitude,
    );

    if (!mounted) return;

    if (nearbyTrees.isNotEmpty) {
      setState(() => _isSaving = false);
      final shouldProceed = await _showDuplicateWarning(nearbyTrees);
      if (shouldProceed != true) return;
      setState(() => _isSaving = true);
    }

    await _saveTree();
  }

  Future<bool?> _showDuplicateWarning(List<TreeData> nearbyTrees) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pohon Kemungkinan Sudah Terdata'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ditemukan pohon lain yang sudah tercatat sangat dekat dengan lokasi ini. '
                    'Periksa kembali sebelum menyimpan — mungkin ini pohon yang sama.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...nearbyTrees.map((t) {
                    final distance = distanceInMeters(
                      _position!.latitude,
                      _position!.longitude,
                      t.latitude,
                      t.longitude,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.species, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${distance.toStringAsFixed(1)} m dari lokasi Anda • oleh ${t.surveyorName}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal, Saya Cek Dulu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tetap Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTree() async {
    final tree = TreeData(
      id: '',
      latitude: _position!.latitude,
      longitude: _position!.longitude,
      photoBase64: _photoBase64!,
      surveyorId: widget.surveyorUser.uid,
      surveyorName: widget.surveyorUser.name,
      species: _effectiveSpecies,
      kecamatan: _effectiveKecamatan,
      kelurahan: _kelurahanController.text.trim(),
      namaJalan: _namaJalanController.text.trim(),
      condition: _condition,
      keteranganKondisi: _requiresKeterangan ? _keteranganKondisiController.text.trim() : '',
      timestamp: DateTime.now(),
      status: TreeStatus.pending,
    );

    final error = await _treeService.createTree(tree);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data pohon berhasil disimpan!'), backgroundColor: Colors.green),
    );

    setState(() {
      _selectedSpecies = null;
      _selectedKecamatan = null;
      _condition = TreeCondition.sehat;
      _customSpeciesController.clear();
      _kecamatanCustomController.clear();
      _kelurahanController.clear();
      _namaJalanController.clear();
      _keteranganKondisiController.clear();
      _photoBytes = null;
      _photoBase64 = null;
      _position = null;
      _locationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Data Pohon')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.my_location,
            title: 'Lokasi GPS',
            children: [
              if (_position != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 150,
                    child: IgnorePointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_position!.latitude, _position!.longitude),
                          initialZoom: 17,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.pemetaanpohon.app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(_position!.latitude, _position!.longitude),
                              width: 40,
                              height: 40,
                              child: Icon(Icons.location_on,
                                  color: _isLocationValid ? Colors.green : Colors.red, size: 36),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_isLocationValid ? Colors.green : Colors.red).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isLocationValid ? Colors.green : Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLocationValid ? Icons.check_circle_outline : Icons.error_outline,
                        color: _isLocationValid ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isLocationValid
                              ? 'Di dalam wilayah Kota Cirebon\n${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                              : 'Lokasi berada di luar wilayah pemetaan Kota Cirebon.',
                          style: TextStyle(
                            color: _isLocationValid ? Colors.green[800] : Colors.red[800],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ] else
                Container(
                  height: 150,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.map_outlined, size: 40, color: Colors.black38),
                ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(_locationError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 4),
              _BigButton(
                onPressed: _isFetchingLocation ? null : _fetchLocation,
                icon: _isFetchingLocation ? null : Icons.my_location,
                loading: _isFetchingLocation,
                label: _position == null ? 'AMBIL LOKASI GPS' : 'AMBIL ULANG LOKASI',
                filled: _position == null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.camera_alt_outlined,
            title: 'Foto Pohon',
            children: [
              if (_photoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_photoBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 40, color: Colors.black38),
                ),
              const SizedBox(height: 10),
              _BigButton(
                onPressed: _takePhoto,
                icon: Icons.camera_alt_outlined,
                label: _photoBytes == null ? 'AMBIL FOTO' : 'AMBIL ULANG FOTO',
                filled: _photoBytes == null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.park_outlined,
            title: 'Detail Pohon',
            children: [
              DropdownButtonFormField<String>(
                value: _selectedSpecies,
                decoration: const InputDecoration(labelText: 'Jenis Pohon', isDense: true),
                hint: const Text('Pilih jenis pohon'),
                items: speciesOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => setState(() => _selectedSpecies = value),
              ),
              if (_selectedSpecies == 'Lainnya') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customSpeciesController,
                  decoration: const InputDecoration(labelText: 'Sebutkan jenis pohon', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Kondisi Pohon', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    tooltip: 'Lihat panduan ciri-ciri',
                    onPressed: _showConditionGuide,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TreeCondition.values.map((c) {
                  final color = treeConditionColor(c);
                  return ChoiceChip(
                    label: Text(c.label),
                    selected: _condition == c,
                    selectedColor: color.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: _condition == c ? color : Colors.black87),
                    side: BorderSide(color: _condition == c ? color : Colors.black26),
                    onSelected: (_) => setState(() => _condition = c),
                  );
                }).toList(),
              ),
              if (_requiresKeterangan) ...[
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    text: 'Keterangan Kondisi Pohon ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(text: '*', style: TextStyle(color: treeConditionColor(_condition))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _keteranganKondisiController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _condition == TreeCondition.sakit
                        ? 'Jelaskan kondisi pohon (mis. daun menguning, batang berlubang)...'
                        : 'Jelaskan alasan pohon dianggap rawan tumbang...',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.location_city_outlined,
            title: 'Lokasi Administratif',
            children: [
              DropdownButtonFormField<String>(
                value: _selectedKecamatan,
                decoration: const InputDecoration(labelText: 'Kecamatan', isDense: true),
                hint: const Text('Pilih kecamatan'),
                items: kecamatanOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (value) => setState(() => _selectedKecamatan = value),
              ),
              if (_selectedKecamatan == 'Lainnya') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _kecamatanCustomController,
                  decoration: const InputDecoration(labelText: 'Sebutkan kecamatan', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _kelurahanController,
                decoration: const InputDecoration(labelText: 'Kelurahan (opsional)', isDense: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _namaJalanController,
                decoration: const InputDecoration(labelText: 'Nama Jalan', hintText: 'Mis. Jl. Siliwangi', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _BigButton(
            onPressed: _canSubmit ? _submit : null,
            icon: _isSaving ? null : Icons.save_outlined,
            loading: _isSaving,
            label: 'SIMPAN DATA POHON',
            filled: true,
            height: 60,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// Kartu pengelompok section form, biar form panjang terasa lebih
// terorganisir/scannable di layar HP, bukan satu list panjang tanpa jeda.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// Tombol aksi utama berukuran besar — mudah ditekan satu tangan di
// lapangan, sesuai prinsip "tombol besar, input sederhana".
class _BigButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final String label;
  final bool filled;
  final bool loading;
  final double height;

  const _BigButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = false,
    this.loading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3));

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: loading ? const SizedBox.shrink() : Icon(icon),
          label: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: loading ? const SizedBox.shrink() : Icon(icon),
        label: child,
      ),
    );
  }
}