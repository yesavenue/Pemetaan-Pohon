import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/tree_pruning_request.dart';
import '../services/pruning_request_service.dart';
import '../utils/cirebon_regions.dart';

const _alasanOptions = [
  'Pohon terlalu rimbun',
  'Dahan mengganggu jalan',
  'Dahan mendekati kabel',
  'Pohon terlalu dekat dengan bangunan',
  'Pohon berpotensi membahayakan',
  'Pohon membutuhkan perapihan',
  'Lainnya',
];

class PublicPruningRequestScreen extends StatefulWidget {
  const PublicPruningRequestScreen({super.key});

  @override
  State<PublicPruningRequestScreen> createState() => _PublicPruningRequestScreenState();
}

class _PublicPruningRequestScreenState extends State<PublicPruningRequestScreen> {
  final _service = PruningRequestService();
  final _picker = ImagePicker();

  final _namaController = TextEditingController();
  final _alamatPemohonController = TextEditingController();
  final _hpController = TextEditingController();
  final _emailController = TextEditingController();
  final _nikController = TextEditingController();
  final _alamatPohonController = TextEditingController();
  final _alasanLainnyaController = TextEditingController();

  String? _selectedKecamatan;
  String? _selectedKelurahan;
  String? _selectedAlasan;

  Position? _position;
  bool _isFetchingLocation = false;
  String? _locationError;

  Uint8List? _fotoPohonBytes;
  String? _fotoPohonBase64;
  Uint8List? _fotoKtpBytes;
  String? _fotoKtpBase64;

  bool _pernyataanBenar = false;
  bool _isSubmitting = false;

  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

  bool get _isEmailValid => _emailRegex.hasMatch(_emailController.text.trim());

  String get _effectiveAlasan =>
      _selectedAlasan == 'Lainnya' ? _alasanLainnyaController.text.trim() : (_selectedAlasan ?? '');

  bool get _canSubmit =>
      !_isSubmitting &&
      _namaController.text.trim().isNotEmpty &&
      _alamatPemohonController.text.trim().isNotEmpty &&
      _hpController.text.trim().isNotEmpty &&
      _isEmailValid &&
      _nikController.text.trim().length == 16 &&
      _alamatPohonController.text.trim().isNotEmpty &&
      _selectedKecamatan != null &&
      _selectedKelurahan != null &&
      _effectiveAlasan.isNotEmpty &&
      _fotoPohonBase64 != null &&
      _fotoKtpBase64 != null &&
      _pernyataanBenar;

  Future<void> _pickPhoto({required bool isKtp}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final photo = await _picker.pickImage(source: source, imageQuality: 40, maxWidth: 900);
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    final base64Str = base64Encode(bytes);

    if (base64Str.length > 350000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto terlalu besar, coba ambil ulang.')),
      );
      return;
    }

    setState(() {
      if (isKtp) {
        _fotoKtpBytes = bytes;
        _fotoKtpBase64 = base64Str;
      } else {
        _fotoPohonBytes = bytes;
        _fotoPohonBase64 = base64Str;
      }
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
        throw Exception('Layanan lokasi (GPS) tidak aktif.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen. Aktifkan lewat pengaturan.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _position = position;
        _isFetchingLocation = false;
      });
    } catch (e) {
      // GPS gagal TIDAK menggagalkan form — cukup tampilkan info,
      // pemohon tetap bisa mengisi alamat secara manual.
      setState(() {
        _locationError = 'Lokasi GPS tidak digunakan. Anda tetap dapat mengisi alamat secara manual.';
        _isFetchingLocation = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    try {
      final request = TreePruningRequest(
        id: '',
        requestNumber: '',
        namaPemohon: _namaController.text.trim(),
        alamatPemohon: _alamatPemohonController.text.trim(),
        nomorHp: _hpController.text.trim(),
        emailPemohon: _emailController.text.trim(),
        nik: _nikController.text.trim(),
        alamatPohon: _alamatPohonController.text.trim(),
        kecamatan: _selectedKecamatan ?? '',
        kelurahan: _selectedKelurahan ?? '',
        alasan: _effectiveAlasan,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        fotoPohonBase64: _fotoPohonBase64!,
        fotoKtpBase64: _fotoKtpBase64!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final requestNumber = await _service.createRequest(request);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSuccessDialog(requestNumber);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan data. Periksa koneksi internet dan coba kembali.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(String requestNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permohonan Berhasil Dikirim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terima kasih. Permohonan perapihan pohon Anda telah berhasil dikirim '
                'dan akan diperiksa oleh petugas DPRKP Kota Cirebon.',
              ),
              const SizedBox(height: 12),
              Text('Nomor Permohonan: $requestNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // tutup dialog
                Navigator.pop(context); // kembali ke halaman sebelumnya
              },
              child: const Text('Selesai'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permohonan Perapihan Pohon')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Silakan lengkapi data berikut untuk mengajukan permohonan '
            'perapihan/pemangkasan pohon kepada DPRKP Kota Cirebon.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Data Pemohon',
            children: [
              TextField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap *', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alamatPemohonController,
                decoration: const InputDecoration(labelText: 'Alamat Pemohon *', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hpController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nomor HP *', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  hintText: 'nama@email.com',
                  isDense: true,
                  errorText: _emailController.text.isNotEmpty && !_isEmailValid
                      ? 'Format email tidak valid'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nikController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 16,
                decoration: const InputDecoration(
                  labelText: 'Nomor KTP/NIK *',
                  helperText: '16 digit sesuai KTP',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Data Pohon',
            children: [
              TextField(
                controller: _alamatPohonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alamat/Lokasi Pohon *',
                  hintText: 'Mis. Jl. Kesambi Raya No. 25',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedKecamatan,
                decoration: const InputDecoration(labelText: 'Kecamatan *', isDense: true),
                hint: const Text('Pilih kecamatan'),
                items: cirebonKecamatanList
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedKecamatan = v;
                  _selectedKelurahan = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedKelurahan,
                decoration: const InputDecoration(labelText: 'Kelurahan *', isDense: true),
                hint: const Text('Pilih kelurahan'),
                items: kelurahanFor(_selectedKecamatan)
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: _selectedKecamatan == null
                    ? null
                    : (v) => setState(() => _selectedKelurahan = v),
              ),
              const SizedBox(height: 16),
              const Text('Lokasi GPS (opsional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Gunakan fitur ini jika Anda sedang berada di lokasi pohon yang ingin dilaporkan.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              if (_position != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lokasi berhasil diperoleh: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_locationError!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ),
              OutlinedButton.icon(
                onPressed: _isFetchingLocation ? null : _fetchLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_position == null ? 'Gunakan Lokasi Saya' : 'Perbarui Lokasi'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Alasan Permohonan',
            children: [
              DropdownButtonFormField<String>(
                value: _selectedAlasan,
                decoration: const InputDecoration(labelText: 'Alasan *', isDense: true),
                hint: const Text('Pilih alasan'),
                items: _alasanOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setState(() => _selectedAlasan = v),
              ),
              if (_selectedAlasan == 'Lainnya') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _alasanLainnyaController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Jelaskan alasan Anda',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Foto Pohon *',
            children: [
              const Text(
                'Upload foto pohon yang ingin dirapikan/pangkas. Pastikan kondisi pohon terlihat jelas.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              if (_fotoPohonBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_fotoPohonBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.park_outlined, size: 36, color: Colors.black38),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(isKtp: false),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_fotoPohonBytes == null ? 'Tambahkan Foto Pohon' : 'Ganti Foto'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Foto KTP *',
            children: [
              const Text(
                'Upload foto KTP untuk keperluan verifikasi data pemohon. Foto ini hanya dapat '
                'dilihat oleh Admin yang berwenang, tidak ditampilkan ke publik.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              if (_fotoKtpBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_fotoKtpBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.badge_outlined, size: 36, color: Colors.black38),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(isKtp: true),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_fotoKtpBytes == null ? 'Tambahkan Foto KTP' : 'Ganti Foto'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _pernyataanBenar,
            onChanged: (v) => setState(() => _pernyataanBenar = v ?? false),
            title: const Text(
              'Saya menyatakan bahwa data yang saya masukkan adalah benar.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('KIRIM PERMOHONAN', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}