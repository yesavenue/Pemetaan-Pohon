import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/tree_pruning_request.dart';
import 'public_pruning_request_screen.dart';
import '../services/pruning_request_service.dart';
import '../widgets/public_navbar.dart';
import '../widgets/public/public_ui.dart';

class PublicTrackingScreen extends StatefulWidget {
  final String? initialCode;
  final Future<Map<String, dynamic>?> Function(String)? lookup;
  final Future<List<Map<String, dynamic>>> Function(String)? loadHistory;
  const PublicTrackingScreen({super.key, this.initialCode, this.lookup, this.loadHistory});
  @override
  State<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends State<PublicTrackingScreen> {
  final _code = TextEditingController();
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _events = [];
  String? _error;
  String? _historyError;
  bool _busy = false;
  late final _service = PruningRequestService();
  @override
  void initState() {
    super.initState();
    _code.text = widget.initialCode ?? '';
    if (_code.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _search(); });
  }
  @override
  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _search() async {
    if (_busy) return;
    final code = _code.text.trim().toLowerCase();
    setState(() { _result = null; _events = []; _error = null; _historyError = null; });
    if (!PruningRequestService.validAccessCode(code)) {
      setState(() => _error = 'Masukkan kode akses 16 karakter dari bukti pengajuan. Kode lama 64 karakter tetap berlaku.');
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await (widget.lookup ?? _service.lookup)(code);
      if (!mounted) return;
      if (data == null) {
        setState(() => _error = 'Permohonan tidak ditemukan. Periksa kembali kode pada bukti pengajuan.');
      } else {
        setState(() => _result = data);
        try {
          final events = await (widget.loadHistory ?? _service.history)(code);
          if (mounted) setState(() => _events = events);
        } catch (_) {
          if (mounted) setState(() => _historyError = 'Status berhasil dimuat, tetapi riwayat belum tersedia. Tekan Periksa status untuk mencoba lagi.');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Pelacakan belum dapat dimuat. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(Object? value) {
    if (value is! Timestamp) return 'Waktu belum tersedia';
    final d = value.toDate().toUtc().add(const Duration(hours: 7));
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';
  }
  String _label(Object? value) => PruningStatus.values.any((s) => s.name == value)
      ? PruningStatus.fromString(value as String).label : 'Status belum tersedia';

  @override
  Widget build(BuildContext context) => PublicScaffold(
    currentPage: PublicPage.permohonan,
    body: PublicPageScroll(children: [PublicContainer(maxWidth: 760, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('LAYANAN WARGA', style: TextStyle(color: PublicUi.green, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        const SizedBox(height: 12),
        const Text('Lacak permohonan Anda', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('Lihat status dan perkembangan permohonan menggunakan kode akses pada bukti pengajuan.'),
        const SizedBox(height: 24),
        PublicPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _code, enabled: !_busy, autocorrect: false, enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Kode akses rahasia', hintText: 'Tempel kode dari bukti pengajuan'),
            onChanged: (_) => setState(() { _result = null; _events = []; _error = null; _historyError = null; }),
            onSubmitted: (_) => _search()),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _search, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search), label: Text(_busy ? 'Memeriksa…' : 'Periksa status')),
          const SizedBox(height: 12),
          const Text('Jaga kerahasiaan kode akses. Pemegang kode dapat melihat status dan riwayat permohonan.', style: TextStyle(fontSize: 13, color: PublicUi.muted)),
        ])),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Semantics(liveRegion: true, child: Text(_error!))),
        if (_result != null) ...[
          const SizedBox(height: 24),
          PublicPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText('${_result!['requestNumber']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Chip(avatar: const Icon(Icons.receipt_long_outlined, size: 18), label: Text(_label(_result!['status']))),
            Text('Diajukan: ${_date(_result!['createdAt'])}'),
            Text('Pembaruan: ${_date(_result!['updatedAt'])}'),
            const SizedBox(height: 12),
            const Text('Status diperbarui oleh admin sesuai perkembangan penanganan. Pengajuan tidak otomatis berarti perapihan sudah disetujui.'),
            if (_result!['status'] == 'ditolak') const Padding(padding: EdgeInsets.only(top: 12), child: Text('Permohonan belum dapat disetujui. Hubungi instansi pengelola dengan menyebutkan nomor permohonan untuk penjelasan lebih lanjut.')),
          ])),
          const SizedBox(height: 24),
          const Text('Riwayat perkembangan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const Text('Maksimal 100 pembaruan terbaru. Waktu ditampilkan dalam WIB.', style: TextStyle(fontSize: 13, color: PublicUi.muted)),
          if (_historyError != null) Text(_historyError!),
          if (_events.isEmpty && _historyError == null && !_busy) const Text('Belum ada riwayat yang tersedia.'),
          for (final event in _events) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline, color: PublicUi.green), title: Text(_label(event['status'])), subtitle: Text(_date(event['at']))),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const PublicPruningRequestScreen())), icon: const Icon(Icons.edit_note), label: const Text('Ajukan permohonan baru')),
        const SizedBox(height: 16),
        const Text('Permohonan lama yang belum memiliki kode akses belum dapat dilacak di halaman ini. Gunakan nomor permohonan saat menghubungi instansi pengelola.', style: TextStyle(fontSize: 13, color: PublicUi.muted)),
      ],
    ))]),
  );
}